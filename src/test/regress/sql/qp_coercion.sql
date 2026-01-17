-- This file contains tests releated to the operations on different types (mainly joins).
-- Some of the tests performed here may be already found inside other files,
-- But it is nice to have a centrilized place to observe and compare behavior of the planners.

set optimizer_enable_mergejoin = false;
set optimizer_enable_nljoin = false;
set enable_mergejoin = false;
set enable_nestloop = false;

-- start ignore
drop table if exists mto_int2;
drop table if exists mto_int4;
drop table if exists mto_int8;
drop table if exists mto_int2_int4;
drop table if exists mto_int4_int8;
drop table if exists mto_float4;
drop table if exists mto_float8;
drop table if exists mto_text;
-- end ingnore

create table mto_int2 as (select a::int2 from generate_series(0, 10) as a) distributed by (a);
create table mto_int4 as (select a::int4 from generate_series(5, 15) as a) distributed by (a);
create table mto_int8 as (select a::int8 from generate_series(10, 20) as a) distributed by (a);
create table mto_int4_int8 as (select gen::int4 as a, gen::int8 as b from generate_series(1, 10) as gen) distributed by (a, b);
create table mto_float8 as (select a::float8 from generate_series(5, 15, 0.5) as a) distributed by (a);
create table mto_text as (select a::text from generate_series(5, 15) as a) distributed by (a);


-- Perform an inner join on all hash opfamiles containing more than one type
-- We shouldn't see any redistributions, because:
--    The postgres-based planner has operators that work on different types
--    ORCA doesn't have support for such operations, but it knows when a cast doesn't change the distribution

explain (verbose) select * from mto_int2 join mto_int4 using(a);
select * from mto_int2 join mto_int4 using(a);

explain select * from mto_int2 join mto_int8 using(a);
select * from mto_int2 join mto_int8 using(a);

explain (verbose) select * from mto_int4 join mto_int8 using(a);
select * from mto_int4 join mto_int8 using(a);

explain (verbose) select * from mto_float4 join mto_float8 using(a);
select * from mto_float4 join mto_float8 using(a);

-- Same thing with the sides swapped
explain (verbose) select * from mto_int4 join mto_int2 using(a);
select * from mto_int4 join mto_int2 using(a);

explain select * from mto_int8 join mto_int2 using(a);
select * from mto_int8 join mto_int2 using(a);

explain (verbose) select * from mto_int8 join mto_int4 using(a);
select * from mto_int8 join mto_int4 using(a);

explain (verbose) select * from mto_float8 join mto_float4 using(a);
select * from mto_float8 join mto_float4 using(a);

-- This logic should work recursively
set optimizer_join_order = query;

explain (verbose)
select * from mto_int2
    join mto_int8 using(a)
    join mto_int4 using(a);

select * from mto_int2
    join mto_int8 using(a)
    join mto_int4 using(a);

reset optimizer_join_order;


-- Confirm that the same logic is correct for other join types
explain (verbose) select * from mto_int2 full join mto_int4 using(a);
select * from mto_int2 full join mto_int4 using(a);

-- BUG: this test is failing for ORCA
explain (verbose) select * from mto_int2 left join mto_int4 using(a);
select * from mto_int2 left join mto_int4 using(a);

explain (verbose) select * from mto_int2 right join mto_int4 using(a);
select * from mto_int2 right join mto_int4 using(a);

explain (verbose)
select * from mto_int4
where exists (select *
              from mto_int2
              where mto_int4.a = mto_int2.a);

select * from mto_int4
where exists (select *
              from mto_int2
              where mto_int4.a = mto_int2.a);

explain (verbose)
select * from mto_int4
where not exists (select *
                  from mto_int2
                  where mto_int4.a = mto_int2.a);

select * from mto_int4
where not exists (select *
                  from mto_int2
                  where mto_int4.a = mto_int2.a);

explain (verbose)
select * from mto_int4
where mto_int4.a not in (select * from mto_int2);

select * from mto_int4
where mto_int4.a not in (select * from mto_int2);

explain (verbose)
select * from mto_int2 natural join mto_int4;
select * from mto_int2 natural join mto_int4;


-- Here, insead of an implcit cast, an explicit one is present
--    The postgres-based planner should require a redistribuion, because
--    distribution of the mto_int2 table is not direcly equal to the left-hand side of the expression
--    ORCA, on the other hand, can see that redistriubion is unnecessary in such case
explain (verbose) select * from mto_int2 join mto_int4 on mto_int2.a::int4 = mto_int4.a;
select * from mto_int2 join mto_int4 on mto_int2.a::int4 = mto_int4.a;


-- The same thing, but with multiple casts in a row.
-- Because the first cast tends to be converted directly to a conversion function,
-- ORCA shouldn't be able to detect coercion chain and should require a redistribution
explain (verbose) select * from mto_float4 as mto_float4_f join mto_float4 as mto_float4_s on mto_float4_f.a::int::float4 = mto_float4_s.a;
select * from mto_float4 as mto_float4_f join mto_float4 as mto_float4_s on mto_float4_f.a::int::float4 = mto_float4_s.a;


-- Сheck that we don't rule out necessary distribuions in the most basic case
explain (verbose) select * from mto_float4 join mto_int4 using(a);
select * from mto_float4 join mto_int4 using(a);

explain (verbose) select * from mto_int4 join mto_text on mto_int4.a = mto_text.a::int4;
select * from mto_int4 join mto_text on mto_int4.a = mto_text.a::int4;


-- ORCA: in order for there queries to work, equivalence expressions should be matched corretly
explain (verbose)
with int8_cte as (select * from mto_int8)
select * from (mto_int2 join int8_cte as cte_1 using(a))
    join (int8_cte as cte_2 join mto_int4 using(a)) using(a);

with int8_cte as (select * from mto_int8)
select * from (mto_int2 join int8_cte as cte_1 using(a))
    join (int8_cte as cte_2 join mto_int4 using(a)) using(a);

explain (verbose)
with int8_cte as (select * from mto_int8)
select * from (mto_int2 join int8_cte as cte_1 using(a))
    join (mto_int4 join int8_cte as cte_2 using(a)) using(a);

with int8_cte as (select * from mto_int8)
select * from (mto_int2 join int8_cte as cte_1 using(a))
    join (mto_int4 join int8_cte as cte_2 using(a)) using(a);


-- Test distribution by multiple keys
explain (verbose)
select * from mto_int2_int4 as t1 join mto_int4_int8 as t2 on (t1.a = t2.a and t1.b = t2.b);
select * from mto_int2_int4 as t1 join mto_int4_int8 as t2 on (t1.a = t2.a and t1.b = t2.b);

explain (verbose)
select * from mto_int2_int4 as t1 join mto_int4_int8 as t2 on (t1.a = t2.b and t1.b = t2.a);
select * from mto_int2_int4 as t1 join mto_int4_int8 as t2 on (t1.a = t2.b and t1.b = t2.a);

explain (verbose)
select * from mto_int2_int4 as t1 join mto_int2 as t2 on (t1.a = t2.a);
select * from mto_int2_int4 as t1 join mto_int2 as t2 on (t1.a = t2.a);

set optimizer_join_order = query;
explain (verbose)
with mto_int2_int4_copy as (select * from mto_int2_int4)
select * from mto_int2_int4
    natural join mto_int4_int8
    natural join mto_int2_int4_copy;

with mto_int2_int4_copy as (select * from mto_int2_int4)
select * from mto_int2_int4
    natural join mto_int4_int8
    natural join mto_int2_int4_copy;
reset optimizer_join_order;


drop table mto_int2;
drop table mto_int4;
drop table mto_int8;
drop table mto_int2_int4;
drop table mto_int4_int8;
drop table mto_float4;
drop table mto_float8;
drop table mto_text;

reset enable_nestloop;
reset enable_mergejoin;
reset optimizer_enable_nljoin;
reset optimizer_enable_mergejoin;

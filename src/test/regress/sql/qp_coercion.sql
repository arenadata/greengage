-- This file contains tests releated to the operations on different types (mainly joins)
-- Some of the tests performed here may be already found inside other files,
-- but it is nice to have a centrilized place where we can obsverve this
-- behavior as a whole
-- The main concern here is redistribtuion mitigation on types with compatible hashfunctions

create schema qp_coercion;
set search_path to qp_coercion;
set optimizer_enable_mergejoin = false;
set optimizer_enable_nljoin = false;
set enable_mergejoin = false;
set enable_nestloop = false;

create table mto_int2 as (select a::int2 from generate_series(0, 10) as a) distributed by (a);
create table mto_int4 as (select a::int4 from generate_series(5, 15) as a) distributed by (a);
create table mto_int8 as (select a::int8 from generate_series(10, 20) as a) distributed by (a);

create table mto_float4 as (select a::float4 from generate_series(0, 10, 0.5) as a) distributed by (a);
create table mto_float8 as (select a::float8 from generate_series(5, 15, 0.5) as a) distributed by (a);

create table mto_text as (select a::text from generate_series(5, 15) as a) distributed by (a);


-- nocommit: better wording?
-- Perform inner join on all opfamiles containing more than one type
-- We shouldn't see any redistributions, because:
-- Postgres-based planner has operators that work on different types
-- ORCA doesn't support this functionality, so it checks that a cast is performed within opfamily
-- boundaries

explain (verbose) select * from mto_int2 join mto_int4 using(a);
select * from mto_int2 join mto_int4 using(a);

explain select * from mto_int2 join mto_int8 using(a);
select * from mto_int2 join mto_int8 using(a);

explain (verbose) select * from mto_int4 join mto_int8 using(a);
select * from mto_int4 join mto_int8 using(a);

explain (verbose) select * from mto_float4 join mto_float8 using(a);
select * from mto_float4 join mto_float8 using(a);

-- nocommit: wording
-- Just in case, to confirm that we don't introduce wierd behavior when it comes to
-- different join types

-- Note, that this test is failing for ORCA
explain (verbose) select * from mto_int2 left join mto_int4 using(a);
select * from mto_int2 left join mto_int4 using(a);

explain (verbose) select * from mto_int2 right join mto_int4 using(a);
select * from mto_int2 right join mto_int4 using(a);

explain (verbose) select * from mto_int2 full join mto_int4 using(a);
select * from mto_int2 full join mto_int4 using(a);

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

-- nocommit: why is this query performed on a coordinator?
explain (verbose)
select * from mto_int4
where mto_int4.a not in (select * from mto_int2);

select * from mto_int4
where mto_int4.a not in (select * from mto_int2);


-- Just in case, test if we can do the thing recusively
-- CTEs are used to make sure that we preserve join order and that
-- the tables on the first level have different distributions
explain (verbose)
select * from mto_int2
    join mto_int4 using(a)
    join mto_int8 using(a);

select * from mto_int2
    join mto_int4 using(a)
    join mto_int8 using(a);


-- Test how we perform when explicit cast is present
explain select * from mto_int2 join mto_int4 on mto_int2.a::int4 = mto_int4.a;
select * from mto_int2 join mto_int4 on mto_int2.a::int4 = mto_int4.a;


-- The same thing, but with multiple casts in a row.
-- Because the first cast tends to be converted directly a conversion function,
-- ORCA shouldn't be able to detect coercion chain and should require a redistribution
explain select * from mto_float4 as mto_float4_f join mto_float4 as mto_float4_s on mto_float4_f.a::int::float4 = mto_float4_s.a;
select * from mto_float4 as mto_float4_f join mto_float4 as mto_float4_s on mto_float4_f.a::int::float4 = mto_float4_s.a;


-- The opposite case, redistribution nodes should be present
explain (verbose) select * from mto_float4 join mto_int4 using(a);
select * from mto_float4 join mto_int4 using(a);

explain (verbose)
select * from mto_int4 join mto_text on mto_int4.a = mto_text.a::int4;
select * from mto_int4 join mto_text on mto_int4.a = mto_text.a::int4;


-- nocommit: wording
-- nocommit: trace how non-modified version mathes distribution column with oid=16
-- ORCA specific test: CTE optimization is different enough from
-- regular optimiazation to is worth to check if it still holds
explain (verbose)
with int8_cte as (select * from mto_int8)
select * from (mto_int2 join int8_cte as cte_1 using(a))
    join (int8_cte as cte_2 join mto_int4 using(a)) using(a);

with int8_cte as (select * from mto_int8)
select * from (mto_int2 join int8_cte as cte_1 using(a))
    join (int8_cte as cte_2 join mto_int4 using(a)) using(a);

-- nocommit: hash aggregate?
-- nocommit: breaking these changes with invalid catalog entries?
-- nocommit: natural join?
-- nocommit: union all?
-- nocommit: tables distributed by multiple keys?
-- nocommit: left join on using with different types
-- nocommit: Add ticket for orca not rebuilding on .h file changes
-- nocommit: Comma syntax?
-- nocommit: self join, with several levels of recursion
-- nocommit: check cardinality for one of the orca unit tests
-- nocommit: swap join sides

reset enable_nestloop;
reset enable_mergejoin;
reset optimizer_enable_nljoin;
reset optimizer_enable_mergejoin;
drop schema qp_coercion cascade;

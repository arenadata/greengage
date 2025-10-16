--
-- Test for parallelizing function scans. 
--

DROP TABLE IF EXISTS intab CASCADE;
 CREATE TABLE intab (
   id int8 primary key,
   data int8);
INSERT INTO intab values (1,1),(2,4),(3,9),(4,16),(5,25),(6,36),(7,49),(8,64);
DROP TABLE IF EXISTS few CASCADE;
CREATE TABLE few(id int, dataa text, datab text);
INSERT INTO few VALUES(1, 'a', 'foo'),(2, 'a', 'bar'),(3, 'b', 'bar');

-- Function which accesses distributed table

CREATE OR REPLACE FUNCTION readtab(int) RETURNS SETOF intab 
EXECUTE ON INITPLAN
AS
$$
DECLARE 
r intab%rowtype;
BEGIN
  FOR r IN SELECT * FROM intab WHERE id < $1 ORDER BY id LOOP
      return next r;
  end loop;
  RETURN;
END
$$ LANGUAGE plpgsql;

-- Functions which depends on its arguemts only

CREATE OR REPLACE FUNCTION genrecs(int) RETURNS SETOF intab IMMUTABLE AS
$$
DECLARE r intab%rowtype;
        i int;
BEGIN
	FOR i in 1..$1 LOOP
		r.id=i;
		r.data=i*i;
		RETURN NEXT r;
	END LOOP;
	RETURN;
END;
$$ LANGUAGE plpgsql;

-- function which accesses master-only table

CREATE OR REPLACE  FUNCTION masteronly(int) RETURNS SETOF intab 
STABLE
EXECUTE ON MASTER AS
$$
DECLARE r intab%rowtype;
        i int;
BEGIN
	FOR i in select dbid FROM gp_segment_configuration WHERE dbid <= $1
	ORDER BY dbid
	LOOP
		r.id=i;
		r.data=i*i;
		RETURN NEXT r;
	END LOOP;
	RETURN;
END;
$$ LANGUAGE plpgsql;

-- simple correlated query

SELECT few.id, a.data FROM genrecs(8) a,few WHERE a.id = few.id;

EXPLAIN SELECT few.id, a.data FROM genrecs(8) a,few  WHERE a.id = few.id;

SELECT few.id, a.data FROM masteronly(8) a,few WHERE a.id = few.id;

EXPLAIN SELECT few.id, a.data FROM masteronly(8) a,few WHERE a.id = few.id;

SELECT few.id, a.data FROM readtab(8) a,few WHERE a.id = few.id;

-- query which is correlated via limit

SELECT (SELECT data FROM genrecs(8) LIMIT 1 OFFSET few.id) FROM few;

EXPLAIN SELECT (SELECT data FROM genrecs(8) LIMIT 1 OFFSET few.id) FROM few;

SELECT (SELECT data FROM masteronly(8) LIMIT 1 OFFSET few.id) FROM few;

EXPLAIN SELECT (SELECT data FROM masteronly(8) LIMIT 1 OFFSET few.id) FROM few;

SELECT (SELECT data FROM readtab(8) LIMIT 1 OFFSET few.id) FROM few;

EXPLAIN SELECT (SELECT data FROM readtab(8) LIMIT 1 OFFSET few.id) FROM few;

DROP TABLE intab CASCADE;
DROP TABLE few CASCADE;

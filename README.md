# Mongo VS Postgres - Large-table performance comparison

This is a simple benchmark that tests how quick Postgres and MongoDB can
concurrently read and write records to a table/collection that has at least
100M records in it.

This kind of benchmark is important to show which DB performs better as an event
log store - think thermostat readings, or when a user (dis)connected to a
chat room, and similar events that just get logged and never updated.

*"But why not go for InfluxDB/TimescaleDB/Clickhouse?"* I hear you ask. I don't
want to add unnecessary complexity if I don't have to. Having a new DB that I
have to learn to use and maintain is something I'd like to avoid given the size
of my team. The only reason I'm looking into Mongo is because I have an expert
in-house.

## Running

To run the benchmark execute

```bash
docker compose run -it --rm app ./benchmark
```

While you can run this locally, my suggestion is that you rent out a VPS and
let the benchmark run there over night. This is very taxing on your SSD and
renting a VPS gives you a consistent comparison platform.

On some systems running the tests in parallel may be unstable. If you experience
mid-test crashes add the following option `... --rm -e "SYNC=true" app ...`

## Results

System:

```
CPU: 12 Core / 24 Thread Ryzen
MEM: 32 GB
SSD: NVME 1TB
```

Output:

```
=== TEST ===

============================ Stock Postgres ===================================
[Postgres] Running test case TestCase::Postgres...
[Postgres] Connecting to the database...
-- create_table(:things, {:force=>true})
   -> 0.0697s
[Postgres] Testing bulk insertion...
[Postgres] = Bulk insertion test finished in 51890.974626113 =
[Postgres] Testing concurrent read-write performance...
[Postgres] = Concurrent read-write test finished in 2941.4025252889987 =

=============================== Postgres ======================================
[Postgres] Running test case TestCase::Postgres...
[Postgres] Connecting to the database...
-- create_table(:things, {:force=>true})
   -> 0.0842s
[Postgres] Testing bulk insertion...

=================== Mongo DB with journaling DISABLED =========================
[MongoDb] Running test case TestCase::MongoDb...
[MongoDb] Connecting to the database...
[MongoDb] Testing bulk insertion...
[MongoDb] = Bulk insertion test finished in 12739.171727085006 =
[MongoDb] Testing concurrent read-write performance...
[MongoDb] = Concurrent read-write test finished in 68.91302931698738 =

=================== Mongo DB with journaling ENABLED ==========================
[MongoDb] Running test case TestCase::MongoDb...
[MongoDb] Connecting to the database...
[MongoDb] Testing bulk insertion...
[MongoDb] = Bulk insertion test finished in 14510.579260853003 =
[MongoDb] Testing concurrent read-write performance...
[MongoDb] = Concurrent read-write test finished in 112.13109906099271 =
```

Notes:
* Mongo used up nearly 15GB of RAM and a few gigs of disk,
    while Postgres used 2GB of RAM and 300GB of disk space.
* Mongo keeps data only in-memory by default, if you want to persist the data
    you have to pass `--journal`  as a startup argument. I guess this is why
    it's called Snapchat of databases. After re-testing with that flag ON Mongo
    started using a lot of disk space and about 8GB of RAM.
* From casual observation of both the Postgres and Mongo DB logs it seems like
    Mongo is much faster when there are less then 50-60M records. Writes last
    about 100ms. But as soon as we pass 60M write times oscillate all the way
    from 100ms to 8s.
* The stock Postgres container is configured to use up to 1.5GB of RAM. I
    changed the config to allow up to 4GB - same as Mongo, though Mongo doesn't
    seem to benefit much from being capped or uncapped.

|                    | Postgres (stock) | MongoDB (no journal) | MongoDB               |
|:-------------------|:-----------------|:---------------------|:----------------------|
| Insertion rate     | ~2000/s          | ~8000/s (x4 better)  | ~7000/s (x3.5 better) |
| Read-write         | ~34/s            | ~1470/s (x43 better) | ~900/s (x26 better)   |

## Disclaimer

*Please remember that all benchmarks are bullshit.* What is important to me
might not be important to you.

*I'm interested in how these databases perform when there are 100M+ records in
a table.* If a DB is super performant with 1-5M records that isn't of much use
to me since my dataset has 500M records currently and is growing.

I didn't test partitioning because I'd just go with Postgres or MariaDB then no
matter how large the performance difference would be. As I said, having one DB
to look at and maintain is much easier for me than having two.

## Other people's benchmarks

* [Postgres 11 vs Mongo 4 (Postgres wins in all aspects, though this is very out-of-date now)](https://info.enterprisedb.com/rs/069-ALB-339/images/PostgreSQL_MongoDB_Benchmark-WhitepaperFinal.pdf)

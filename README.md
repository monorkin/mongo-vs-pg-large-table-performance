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

There are many configuration options that you can pass to `./benchmark`. To see
them pass `--help`. They allow you to configure the concurrency and size of the
read-write test, the base size of the database-under-test, define which tests
to perform against which database instances, and more.


## Notes

Here are a few things I have learned while performing this benchmark.
Watch out for them when running you own benchmark:

* The stock Postgres container is configured to use up to 1.5GB of RAM. I
    changed the config to allow up to 4GB - same as Mongo, though Mongo doesn't
    seem to benefit much from being capped or uncapped.
* The stock MongoDB configuration doesn't enable write-ahead logs/journaling.
    **[Without this enabled MongoDB will write data to disk once every minute.](https://www.mongodb.com/docs/manual/reference/command/fsync/)**
    This means that **any unexpected interrupt will lead to the last minute of
    data being lost**. [With journaling enabled MongoDB can recover from an unexpected stop](https://www.mongodb.com/docs/manual/core/journaling/).
    Journaling has a significant performance impact which is dependant on the
    number of clients connections to an instance.
* **[Postgres has a mode where it works similarly to MongoDB](https://www.percona.com/blog/postgresql-synchronous_commit-options-and-synchronous-standby-replication/).** If you disable
    `synchronous_commit` then data will be written to disk every 100ms instead of being
    written immediately. **This improves write speed 5x to 10x which makes it comparable to MongoDB**.
* **Running this benchmark on Apple Silicone Macs will skew the results.**
    [For historical reasons, Macs have different ways of instructing the OS to write data to disk from other Unix systems](https://eclecticlight.co/2022/02/18/how-can-you-trust-a-disk-to-write-data/).
    **TL;DR calling fsync on a Mac doesn't actually persist the data to disk, and [this has been known for years](https://erlang.org/pipermail/erlang-patches/2008-July/000258.html) but was [recently under the spotlight](https://news.ycombinator.com/item?id=30370551).**
    This means that if one database-under-test isn't aware of that and implements
    persistence to disk using different system calls from the other
    software-under-test this could cause it to perform better than it
    would on other hardware or operating systems.
    **Therefore, a fairer comparison between different databases is to run this
    benchmark on a Linux machine, as it ensures that fsync behaves exactly the
    same way for all software.**

## Result

The following are the results of this benchmark with the test cases defined
in [cases.yml](./cases.yml).
(reference the [docker-compose.yml](./docker-compose.yml) file to see the individual DB configs)

**System:**

```
AWS m7a.large
CPU: 2 vCPU
RAM: 8 GB RAM
DISK: 200GB
```

**Output:**

```
```

**Comparison:**

**Conclusions:**

## Disclaimer

*Please remember that all benchmarks are bullshit.* What is important to me
might not be important to you.

*I'm interested in how these databases perform when there are 100M+ records in
a table.* If a DB is super performant with 1-5M records that isn't of much use
to me since my dataset has 500M records currently and is growing.

I didn't test partitioning because I'd just go with Postgres or MariaDB then no
matter how large the performance difference would be. As I said, having one DB
to look at and maintain is much easier for me than having two.

## Other people's benchmarks & other relevant link

* [Postgres 11 vs Mongo 4 (Postgres wins in all aspects, though this is very out-of-date now)](https://info.enterprisedb.com/rs/069-ALB-339/images/PostgreSQL_MongoDB_Benchmark-WhitepaperFinal.pdf)
* [MongoDB docs: Synchronous writing and default disk flushing config](https://www.mongodb.com/docs/manual/reference/command/fsync/)
* [MongoDb docs: Journaling](https://www.mongodb.com/docs/manual/core/journaling/)
* [Postgres' synchronous_commit command](https://www.percona.com/blog/postgresql-synchronous_commit-options-and-synchronous-standby-replication/)
* [Difference in fsync semantics on MacOS and other Unix system](https://eclecticlight.co/2022/02/18/how-can-you-trust-a-disk-to-write-data/)
* [Erlang issue, from 15 years ago, about the MacOS fsync semantics](https://erlang.org/pipermail/erlang-patches/2008-July/000258.html)
* [Hacker News discussion about the fsync semantics on MacOS and synchronous write performance in M1 Macs](https://news.ycombinator.com/item?id=30370551)

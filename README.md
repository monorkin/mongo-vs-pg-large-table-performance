# Mongo VS Postgres - Large-table performance comparison

This is a simple benchmark that tests how quick Postgres and MongoDB can
concurrently read and write records to a table/collection that has at least
100M records in it.

This kind of benchmark is important to show which DB performs better as an event
log store - think thermostat readings, or when a user (dis)connected to a
chat room, and smiler event that just get logged and never updated.

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
```

## Disclaimer

Please remember that all benchmarks are bullshit. What is important to me
might not be important to you.

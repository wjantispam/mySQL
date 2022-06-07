# Installation and Issues on WSL2

sudo service mariadb start


    $> ps -ef | grep mysql
    dean     12960  5439  0 11:50 ?        00:00:00 /bin/sh /usr/bin/mysqld_safe
    dean     13049 12960  0 11:50 ?        00:00:00 /usr/sbin/mariadbd --basedir=/usr --datadir=/home/dean/data/mysql/ --plugin-dir=/usr/lib/mysql/plugin --log-error=/home/dean/logs/mysql/mysql.log --pid-file=DESKTOP-9P4ULB5.pid --socket=/var/lib/mysql/mysql.sock --port=3333

    $> mysql --socket=/var/lib/mysql/mysql.sock
    Welcome to the MariaDB monitor.  Commands end with ; or \g.
    Your MariaDB connection id is 3
    Server version: 10.5.16-MariaDB-1:10.5.16+maria~bullseye mariadb.org binary distribution

    Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

    Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

    MariaDB [(none)]>


## Issues
This is how mariadb strats up. Always try to check error log first, and try to ping down from the following places:

/etc/init.d/mariadb calls /usr/bin/mysqld_safe and it uses user config  /home/dean/.my.cnf

    $> cat /home/dean/.my.cnf

    [client-server]
    port=3333

    [mariadb]
    user=dean
    datadir=/home/dean/data/mysql/
    socket=/var/lib/mysql/mysql.sock
    log-error=/home/dean/logs/mysql/mysql.log


$> /etc/init.d/mariadb start
Starting MariaDB database server: mariadbdinstall: cannot change owner and permissions of ‘/run/mysqld’: No such file or directory
The fix is simply: $> sudo mkdir /run/mysqld

You will need to chmod -R 777 /var/lib/mysql


# Data generator
## Sequence Engine
A lot of ideas from: https://falseisnotnull.wordpress.com/2013/06/23/mariadbs-sequence-storage-engine/
The sequence engine is particularly useful with joins and subqueries. 
For example, this query finds all prime numbers below 50:
    MariaDB [test]> SELECT seq FROM seq_2_to_50 s1 WHERE 0 NOT IN (SELECT s1.seq % s2.seq FROM seq_2_to_50 s2 WHERE s2.seq <= sqrt(s1.seq));
    +-----+
    | seq |
    +-----+
    |   2 |
    |   3 |
    |   5 |
    |   7 |
    |  11 |
    |  13 |
    |  17 |
    |  19 |
    |  23 |
    |  29 |
    |  31 |
    |  37 |
    |  41 |
    |  43 |
    |  47 |
    +-----+
    15 rows in set (0.000 sec)

And almost (without 2, the only even prime number) the same result with joins:
    MariaDB [test]> SELECT s1.seq FROM seq_2_to_50 s1 JOIN seq_2_to_50 s2
        ->   WHERE s1.seq > s2.seq AND s1.seq % s2.seq <> 0
        ->   GROUP BY s1.seq HAVING s1.seq - COUNT(*) = 2;
    +-----+
    | seq |
    +-----+
    |   3 |
    |   5 |
    |   7 |
    |  11 |
    |  13 |
    |  17 |
    |  19 |
    |  23 |
    |  29 |
    |  31 |
    |  37 |
    |  41 |
    |  43 |
    |  47 |
    +-----+
    14 rows in set (0.002 sec)

Find multiples of both 3 and 5
    SELECT s1.seq FROM seq_5_to_100_step_5 s1 INNER JOIN seq_3_to_100_step_3 s2 ON s1.seq = s2.seq;

Sequence of 1-char strings
    SELECT CHAR(seq) AS ch
        FROM (
                    -- lowercase
                    (SELECT seq FROM seq_97_to_122 l)
                UNION
                    -- uppercase
                    (SELECT seq FROM seq_65_to_90 u)
                UNION
                    -- digits
                    (SELECT seq FROM seq_48_to_57 d)
            ) ch;
Sequence of hours, halfes of an hour, etc
    -- Hours in a day
    SELECT CAST('00:00:00' AS TIME) + INTERVAL (s.seq - 1) HOUR AS t
        FROM (SELECT seq FROM seq_1_to_24) s;
    -- Halfes of an hour in a day
    SELECT CAST('00:00:00' AS TIME) + INTERVAL (30 * s.seq) MINUTE AS t
        FROM (SELECT seq FROM seq_1_to_48) s;

Sequence tables can also be useful in date calculations. 
    MariaDB [test]> SELECT DAYNAME('1980-12-05' + INTERVAL (seq) YEAR) day,     '1980-12-05' + INTERVAL (seq) YEAR date FROM seq_0_to_10;
    +-----------+------------+
    | day       | date       |
    +-----------+------------+
    | Friday    | 1980-12-05 |
    | Saturday  | 1981-12-05 |
    | Sunday    | 1982-12-05 |
    | Monday    | 1983-12-05 |
    | Wednesday | 1984-12-05 |
    | Thursday  | 1985-12-05 |
    | Friday    | 1986-12-05 |
    | Saturday  | 1987-12-05 |
    | Monday    | 1988-12-05 |
    | Tuesday   | 1989-12-05 |
    | Wednesday | 1990-12-05 |
    +-----------+------------+
    11 rows in set (0.000 sec)

## FOUND_ROWS

Ref: https://github.com/bobsense/mysql-arm64/blob/ba4110f6af182331eda2aad8fa4fd4069729515b/percona-server-5.6.22-72.0/mysql-test/t/select_found.test



```sql
    create or replace table t1 (a int not null auto_increment, b int not null, primary key(a));
    insert into t1 (b) values (2),(3),(5),(5),(5),(6),(7),(9);
    select SQL_CALC_FOUND_ROWS * from t1;
    select found_rows();  -- 8
    select SQL_CALC_FOUND_ROWS * from t1 limit 1; -- Assume you used limit and got the answer
    -- with SQL_CALC_FOUND_ROWS and FOUND_ROWS you can get the total with running the query without the limit again
    select found_rows();  -- 8    
    select SQL_BUFFER_RESULT SQL_CALC_FOUND_ROWS * from t1 limit 1;
    select found_rows();  -- 8
    select SQL_CALC_FOUND_ROWS * from t1 order by b desc limit 1;
    select found_rows();  -- 8
    select SQL_CALC_FOUND_ROWS distinct b from t1 limit 1;
    select found_rows();  -- 6
    select SQL_CALC_FOUND_ROWS b,count(*) as c from t1 group by b order by c desc limit 1;
    select found_rows();  -- 6
    select SQL_CALC_FOUND_ROWS * from t1 left join t1 as t2 on (t1.b=t2.a) limit 2,1;
    select found_rows();  -- 8
    drop table t1;
```


## LAST_INSERT_ID




insert into t1 (b) values (2),(3),(5),(5),(5),(6),(7),(9);
    select * from t1;
    select found_rows();

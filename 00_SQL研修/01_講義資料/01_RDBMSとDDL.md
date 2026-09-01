# SQL 基礎：データベースとテーブル

## 導入：データベースと RDBMS

この講義では、リレーショナルデータベース（RDB）の基本的な概念と、それらを操作するための SQL（Structured Query Language）の基礎を学びます。特に、PostgreSQL を例に具体的な操作を見ていきますが、ここで学ぶ知識は他の主要な RDBMS（MySQL, Oracle Database, SQL Server など）にも広く応用できます。

> テーブルをどう分けるかという設計の考え方は [[00_なぜテーブルを分けるのか]]、用語の索引は [[用語集]] にあります。

### データベースとは？

**データベース**とは、整理され、構造化された情報の集合体のことです。データを効率的に保存、管理、検索するために使用されます。

### RDBMS（リレーショナルデータベース管理システム）とは？

**RDBMS**は、リレーショナルデータベースを管理するためのソフトウェアです。データを**テーブル**という形式で管理し、テーブル間の関係性（リレーション）を定義できるのが特徴です。

### テーブルとは?

**テーブル**は、データベース内でデータを格納する基本的な構造です。Excel のスプレッドシートのように、行と列で構成されます。

- **列（カラム、フィールド）**: 特定の種類のデータを格納します（例: ユーザー名、商品の価格）。
- **行（レコード、タプル）**: 1 つのエンティティ（例: 1 人のユーザー、1 つの商品）に関するすべての情報を格納します。

## データベースの作成：CREATE DATABASE

新しいデータベースを作成する際に使用するコマンドです。

### 基本構文

```SQL
CREATE DATABASE データベース名;
```

### 例

my_company_db という名前のデータベースを作成します。

```SQL
CREATE DATABASE my_company_db;
```

### 考慮事項

- **データベース名**: ユニークでなければなりません。
- **権限**: PostgreSQL では、CREATE DATABASE を実行するには**スーパーユーザー権限**または CREATEDB ロールが必要です。実務では権限管理が重要になるため、適切な権限を持つユーザーで実行しましょう。
- **文字エンコーディング**: 日本語を扱う場合は、UTF8 を指定することが多いです。（例: `CREATE DATABASE my_db ENCODING 'UTF8';`）
- **所有者（Owner）**: データベースの所有者を指定できます。（例: `CREATE DATABASE my_db OWNER user_name;`）

> 🐘 **どこまで通じる話か**
> 「データベース」と「スキーマ」の関係は製品によって違います。PostgreSQL は**1つのデータベースの内部に複数のスキーマ**を持ちます。一方 Oracle では「スキーマ」がユーザー（アカウント）に紐づく論理的な領域を指します。用語の定義や階層が異なるので、他DBの経験がある人ほど混同しやすいところです。

## テーブルの作成：CREATE TABLE

データベース内に新しいテーブルを作成するコマンドです。テーブル名、列名、データ型、および制約を定義します。

### 基本構文

```SQL
CREATE TABLE テーブル名 (
    列名1 データ型 [列制約],
    列名2 データ型 [列制約],
    ...
    [テーブル制約]
);
```

列に指定できるデータ型は [[01_データ型]] にまとめてあります。

### 命名規則の注意点

テーブル名や列名には、以下の点に注意して命名しましょう。

- **半角英数字とアンダースコア（\_）**: これらを使用することが一般的です。
- **スネークケース**: `user_id`, `product_name` のように、単語間をアンダースコアで繋ぐ**スネークケース**が推奨されます。
- **予約語の回避**: SQL のキーワード（`SELECT`, `FROM`, `WHERE` など）はそのままでは名前に使えません。ダブルクォーテーションで囲めば使えますが、非推奨です。
- **読みやすさ**: テーブルや列の役割がわかるような、意味のある名前をつけましょう。

⚠️ **ダブルクォーテーションで囲むと、大文字・小文字が固定される。** PostgreSQL はクォートしない識別子を**すべて小文字に畳みます**。そのため `"userId"` のように作った列は、以後**参照するたびにクォートし続けなければなりません**（実測）。

```sql
CREATE TABLE u("userId" int, user_id int);
SELECT userId FROM u;
```

```
ERROR:  column "userid" does not exist
LINE 1: SELECT userId FROM u;
               ^
HINT:  Perhaps you meant to reference the column "u.userId" or the column "u.user_id".
```

スネークケースが推奨されるのは、**この面倒を最初から避けられるから**です。

### 制約の書き方：列制約とテーブル制約

制約は**書く場所**が2通りあります。基本構文の `[列制約]` と `[テーブル制約]` がこれにあたります。

```SQL
CREATE TABLE grades (
    student_id INTEGER NOT NULL,          -- ← 列制約：列の定義の後ろに書く
    course_id  INTEGER NOT NULL,
    grade      VARCHAR(2),
    PRIMARY KEY (student_id, course_id)   -- ← テーブル制約：列を全部書いた後に単独で書く
);
```

|            | 列制約（Column Constraint）                                        | テーブル制約（Table Constraint）                              |
| :--------- | :------------------------------------------------------------- | :---------------------------------------------------- |
| 書く場所       | 列の定義の後ろ                                                        | 列の並びをすべて書いた後                                          |
| 対象にできる列    | **その1列だけ**                                                     | **複数の列にまたがれる**                                        |
| 書けるもの      | `NOT NULL` / `DEFAULT` / `UNIQUE` / `PRIMARY KEY` / `CHECK` / `REFERENCES` | `UNIQUE` / `PRIMARY KEY` / `CHECK` / `FOREIGN KEY`    |

⚠️ **複数の列にまたがる制約は、テーブル制約でしか書けません。** 複合主キー `PRIMARY KEY (a, b)` や複合外部キーは必ずこの形になります。逆に **`NOT NULL` と `DEFAULT` はテーブル制約として書けません**（構文エラーになります）。列に1つずつ付けてください。

### NOT NULL

その列に NULL（値がない状態）を許可しません。

```SQL
CREATE TABLE users (
    user_id INTEGER PRIMARY KEY,
    name    VARCHAR(100) NOT NULL   -- name は null を許さない
);
```

### UNIQUE

その列の全ての値が一意であることを保証します。NULL は複数存在できます。

```SQL
CREATE TABLE employees (
    employee_id INTEGER PRIMARY KEY,
    email       VARCHAR(255) UNIQUE  -- email は重複を許さない
);
```

| employee_id | email           |
| ----------- | --------------- |
| 1           | AAA@gmail.co.jp |
| 2           | BBB@gmail.co.jp |
| 3           | **(NULL)**      |
| 4           | **(NULL)**      |

`NULL` は「値が不明」という状態なので、**いくつあっても重複とは見なされません**（→ [[01_データ型]] の NULL の節）。

### PRIMARY KEY (主キー)

テーブルの各行を一意に識別するための**列**または**列の組み合わせ**です。

- NOT NULL と UNIQUE の両方の特性を自動的に持ちます。
- テーブルごとに 1 つだけ設定できます。

```SQL
CREATE TABLE products (
    product_id   INTEGER PRIMARY KEY,     -- product_id が主キー
    product_name VARCHAR(255) NOT NULL
);
```

#### 複合主キー (Composite Primary Key)

主キーは、単一の列だけでなく、**複数の列の組み合わせ**で構成することも可能です。これを**複合主キー**と呼びます。複合主キーの場合、その**組み合わせた値がテーブル全体で一意かつ NULL でない**ことを保証します。テーブル全体の主キーは**論理的に 1 つ**とみなされます。

複数列にまたがるので、書き方は必ず**テーブル制約**になります。

**例:** ある学生が複数の科目を受講している場合に、学生 ID と科目 ID の組み合わせで一意に成績を特定するテーブルを考えます。

```SQL
CREATE TABLE grades (
    student_id INTEGER,
    course_id  INTEGER,
    grade      VARCHAR(2),
    PRIMARY KEY (student_id, course_id)   -- 組み合わせが主キー
);
```

この例では、

- student_id が 1 で course_id が 101 の組み合わせは 1 つしか存在できません。
- student_id が 1 で course_id が 102 の組み合わせは別の行として存在できます。

このように、個々の列は重複しても、組み合わせとして重複しないことで一意性を保証します。

#### PRIMARY KEY と UNIQUE の違い

どちらも値の一意性を保証しますが、次の違いがあります。

| 特徴               | PRIMARY KEY                | UNIQUE                       |
| :--------------- | :------------------------- | :--------------------------- |
| **NULL の許容**     | **不可**（NOT NULL を自動的に持つ）   | **可**（複数の NULL が存在できる）        |
| **テーブルあたりの数**    | 1 つのみ（単一列または複合列として）        | 複数設定できる                      |
| **目的**           | 行を一意に識別するための「主たるキー」        | 指定した列（の組み合わせ）の値が重複しないことを保証する  |
| **自動で作られるインデックス** | btree の unique index       | btree の unique index（**同じもの**） |

> 🐘 **「主キーはクラスタードインデックスになる」は PostgreSQL の話ではない**
> そう説明されることがありますが、それは SQL Server や MySQL(InnoDB) の仕組みです。**PostgreSQL にクラスタード／非クラスタードという区別はありません**。PK も UNIQUE も同じ btree unique index が作られるだけで、テーブル本体（ヒープ）の並び順とは無関係です。→ [[17-1_導入_物理構造とスキャン方式]]

### 主キーの自動採番（IDENTITY / SERIAL）

主キーには、新しい行が追加されるたびに自動的に一意の値を生成する機能を持たせることがよくあります。PostgreSQL には2通りの書き方があります。

| 書き方                            | 位置づけ                                          |
| :----------------------------- | :-------------------------------------------- |
| `GENERATED ... AS IDENTITY`    | **SQL標準**。PostgreSQL 10 以降で使える。**新規ならこちら**    |
| `SERIAL` / `BIGSERIAL`         | PostgreSQL 独自の疑似データ型。既存のコードでよく見かける             |

```SQL
-- SQL標準（推奨）
CREATE TABLE example_identity (
    id   INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    data TEXT
);

-- PostgreSQL 独自
CREATE TABLE example_serial (
    id   SERIAL PRIMARY KEY,
    data TEXT
);
```

⚠️ **`GENERATED ALWAYS` と `GENERATED BY DEFAULT` の選び間違いで INSERT が通らなくなる。** `ALWAYS` は id を明示指定した INSERT を**拒否します**（実測）。

```sql
CREATE TABLE ga(id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY, data TEXT);
INSERT INTO ga(data) VALUES ('ok');          -- 通る
INSERT INTO ga(id, data) VALUES (100, 'ng'); -- 通らない
```

```
ERROR:  cannot insert a non-DEFAULT value into column "id"
DETAIL:  Column "id" is an identity column defined as GENERATED ALWAYS.
HINT:  Use OVERRIDING SYSTEM VALUE to override.
```

`ALWAYS` は「採番を DB に完全に任せ、アプリから id を渡させない」ための指定です。データ移行などで既存の id を投入する必要があるなら `BY DEFAULT` を選びます。

シーケンスそのものの仕組み（作成、現在値の確認と設定、`SERIAL` との関係）は [[99_補足_sequenceについて]] にまとめてあります。

> 🐘 **どこまで通じる話か**
> 自動採番は**RDBMS ごとに書き方が大きく違います**。MySQL は `AUTO_INCREMENT`、Oracle は `GENERATED AS IDENTITY` またはシーケンス＋トリガー。標準SQLなのは `GENERATED ... AS IDENTITY` なので、移植を考えるならこちらに寄せます。

### DEFAULT

値を指定しなかった場合に、自動的に設定されるデフォルト値を定義します。

```SQL
CREATE TABLE orders (
    order_id   INTEGER PRIMARY KEY,
    order_date DATE DEFAULT CURRENT_DATE  -- デフォルトで現在の日付が設定される
);
```

### CHECK

その列に挿入される値が、指定された条件を満たしていることを強制します。

```SQL
CREATE TABLE students (
    student_id INTEGER PRIMARY KEY,
    age        INTEGER CHECK (age >= 0 AND age <= 150)  -- 年齢は 0 から 150 の範囲
);
```

### FOREIGN KEY (外部キー)

他のテーブルの PRIMARY KEY または UNIQUE 列を参照する列です。テーブル間の関連性を定義し、参照整合性を維持します。

例: orders テーブルの customer_id が、customers テーブルの customer_id を参照するようにします。

```SQL
CREATE TABLE customers (
    customer_id   INTEGER PRIMARY KEY,
    customer_name VARCHAR(255) NOT NULL
);

CREATE TABLE orders (
    order_id    INTEGER PRIMARY KEY,
    customer_id INTEGER,
    order_date  DATE,
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
);
```

customers：

| **customer_id** | customer_name |
| --------------- | ------------- |
| 1               | bob           |
| 2               | jon           |

orders：

| order_id | **customer_id**   | order_date |
| -------- | ----------------- | ---------- |
| 1        | 1                 | 2025/11/1  |
| 2        | 1                 | 2025/11/2  |
| 3        | 2                 | 2025/11/2  |
| 4        | **3 ← エラーになる** | 2025/11/3  |

被参照側（customers）に存在しない `customer_id` は入れられません。これが**参照整合性**です。

#### 外部キーの参照動作 (ON DELETE, ON UPDATE)

外部キー制約には、参照先の親テーブルの行が削除されたり、主キーが更新されたりした場合に、子テーブルの行をどのように扱うかを定義するオプションがあります。これは実務で非常に重要です。

| オプション         | 動作                                | 注意                                        |
| :------------ | :-------------------------------- | :---------------------------------------- |
| `NO ACTION`   | **既定**。参照している子の行があれば**エラー**にして拒否する | 制約を `DEFERRABLE` にすればチェックをトランザクション末尾まで遅らせられる |
| `RESTRICT`    | 同じくエラーにして拒否する                     | `NO ACTION` と違い、**チェックを遅らせられない**（常に即時）     |
| `CASCADE`     | 子の行も**一緒に削除／更新**される               | 消えてよい行かを必ず確認する。履歴テーブルに使うと記録が失われる           |
| `SET NULL`    | 子の外部キー列を `NULL` にする               | **その列が `NOT NULL` だとエラーになる**（下記）           |
| `SET DEFAULT` | 子の外部キー列をデフォルト値にする                 | そのデフォルト値が親に存在しないと参照整合性違反になる                |

```SQL
CREATE TABLE orders (
    order_id    INTEGER PRIMARY KEY,
    customer_id INTEGER,
    order_date  DATE,
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
        ON DELETE CASCADE    -- 親の顧客が削除されたら、その顧客の注文も削除する
        ON UPDATE RESTRICT   -- 親の顧客 ID の更新は、参照している注文があれば拒否する
);
```

既定が `NO ACTION`（＝親側の削除がエラーになる）であることは、必ず押さえておいてください。

⚠️ **`SET NULL` は、外部キー列が `NOT NULL` だと削除時に失敗します。** 制約を書いた時点ではエラーにならず、**実際に親を削除した瞬間に落ちます**（実測）。

```sql
CREATE TABLE child(
    id        INTEGER PRIMARY KEY,
    parent_id INTEGER NOT NULL REFERENCES parent(id) ON DELETE SET NULL
);
DELETE FROM parent WHERE id=1;
```

```
ERROR:  null value in column "parent_id" of relation "child" violates not-null constraint
DETAIL:  Failing row contains (1, null).
```

#### 外部キーにインデックスは作られない

`PRIMARY KEY` と `UNIQUE` は、一意性を守るためにインデックスが**自動で作られます**。しかし**外部キー列には作られません**（実測）。

```sql
CREATE TABLE customers (customer_id INTEGER PRIMARY KEY, email VARCHAR(255) UNIQUE);
CREATE TABLE orders (
    order_id    INTEGER PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id)
);
SELECT tablename, indexname FROM pg_indexes WHERE schemaname='public' ORDER BY 1, 2;
```

```
 tablename |      indexname
-----------+---------------------
 customers | customers_email_key   ← UNIQUE から自動生成
 customers | customers_pkey        ← PRIMARY KEY から自動生成
 orders    | orders_pkey           ← PRIMARY KEY から自動生成
```

`orders.customer_id` には**何も作られていません**。外部キーは結合や絞り込みで最もよく使う列なので、必要なら自分で `CREATE INDEX` を張る必要があります。実務で最も多いインデックスの貼り忘れがここです。→ [[17-2_実践_EXPLAINの読み方]] ケース2

## テーブル構造の変更と削除

### テーブルの削除：DROP TABLE

既存のテーブルをデータベースから完全に削除します。

#### 基本構文

```SQL
DROP TABLE テーブル名;
```

#### 例

users テーブルを削除します。

```SQL
DROP TABLE users;
```

#### 重要なオプション

- `IF EXISTS`: テーブルが存在しない場合でもエラーを出さずに実行します。スクリプトの実行時に便利です。

```SQL
DROP TABLE IF EXISTS old_table;
```

- `CASCADE`: そのテーブルに**依存しているオブジェクト**（外部キー制約、ビューなど）を一緒に削除します。

参照されているテーブルは、`CASCADE` なしでは削除できません（実測）。

```sql
DROP TABLE customers;
```

```
ERROR:  cannot drop table customers because other objects depend on it
DETAIL:  constraint orders_customer_id_fkey on table orders depends on table customers
HINT:  Use DROP ... CASCADE to drop the dependent objects too.
```

⚠️ **`CASCADE` で消えるのは依存オブジェクトだけで、子テーブルは消えません。** 「関連するテーブルも道連れで消える」わけではありません（実測）。

```sql
DROP TABLE customers CASCADE;
```

```
NOTICE:  drop cascades to constraint orders_customer_id_fkey on table orders
DROP TABLE
```

```
         List of relations
 Schema |  Name  | Type  |  Owner
--------+--------+-------+----------
 public | orders | table | postgres    ← orders は残っている
```

消えたのは `orders` に付いていた**外部キー制約**だけです。結果として orders は「もう存在しない顧客を参照する行」を持てるようになるので、`CASCADE` を使ったら整合性の確認が必要です。

#### 実務での注意点

DROP TABLE はテーブルとデータを完全に削除するため、**本番環境で安易に実行することはほとんどありません**。データ削除が必要な場合は、代わりに以下の方法を検討します。

- **TRUNCATE TABLE**: テーブル構造は残し、全ての行を高速に削除します。行を1件ずつ消すのではないため `DELETE` より速いです。
- **DELETE FROM**: WHERE 句で条件を指定して一部のデータを削除したり、全データを削除したりできます。
- **論理削除**: テーブルからデータを物理的に削除するのではなく、削除フラグ（例: `is_deleted BOOLEAN DEFAULT FALSE`）を立てて、そのデータが「削除された」状態であることを示す方法です。データ復旧が容易ですが、クエリが複雑になることがあります。

⚠️ **「TRUNCATE はロールバックできない」は PostgreSQL では誤り。** PostgreSQL は DDL もトランザクションの中で扱えるため、`TRUNCATE` は `ROLLBACK` で元に戻ります（実測）。

```sql
CREATE TABLE t(v int); INSERT INTO t VALUES (1),(2),(3);
BEGIN;
  TRUNCATE t;
  SELECT count(*) FROM t;   -- 0
ROLLBACK;
SELECT count(*) FROM t;     -- 3 … 戻っている
```

> 🐘 **どこまで通じる話か**
> これは PostgreSQL の性質です。Oracle や MySQL では `TRUNCATE` が暗黙のコミットを伴うため、ロールバックできません。**他DBの経験がある人ほど間違えます。** → [[15-1_導入_トランザクションとACID]]

### テーブル構造の変更：ALTER TABLE

既存のテーブルの構造を変更する際に使用します。

⚠️ **`ALTER TABLE` は対象テーブルに `ACCESS EXCLUSIVE` ロックを取ります**（実測）。このロックの間、そのテーブルは **`SELECT` すらできません**。稼働中のシステムで軽い気持ちで実行すると、アクセスが止まります。

```sql
BEGIN;
ALTER TABLE orders ADD COLUMN memo text;
SELECT relation::regclass AS 対象, mode AS ロックモード
  FROM pg_locks WHERE relation='orders'::regclass AND locktype='relation';
```

```
  対象  |    ロックモード
--------+---------------------
 orders | AccessExclusiveLock
```

ロックの読み方は [[15-2_実践_ロックとMVCC]] で扱います。

#### 列の追加：ADD COLUMN

新しい列をテーブルに追加します。

```SQL
ALTER TABLE テーブル名 ADD COLUMN 新しい列名 データ型 [制約];
```

例: products テーブルに price 列を追加します。

```SQL
ALTER TABLE products ADD COLUMN price NUMERIC(10, 2) DEFAULT 0.00;
```

#### 列の削除：DROP COLUMN

既存の列をテーブルから削除します。

```SQL
ALTER TABLE テーブル名 DROP COLUMN 列名;
```

例: employees テーブルから email 列を削除します。

```SQL
ALTER TABLE employees DROP COLUMN email;
```

> 🐘 `ALTER TABLE DROP COLUMN` は多くの RDBMS でサポートされていますが、Oracle の古いバージョンなど、一部の製品やバージョンでは直接サポートされていなかったり、特定の制約があったりします。実務で実行する際は、使用している RDBMS のバージョンを確認しましょう。

#### 列のデータ型変更：ALTER COLUMN TYPE

既存の列のデータ型を変更します。

```SQL
ALTER TABLE テーブル名 ALTER COLUMN 列名 TYPE 新しいデータ型;
```

例: products テーブルの product_name 列の長さを変更します。

```SQL
ALTER TABLE products ALTER COLUMN product_name TYPE VARCHAR(500);
```

⚠️ **入っているデータが収まらない縮小は失敗します**（実測）。桁を狭める変更は、先に既存データを確認してください。

```sql
CREATE TABLE p2(name VARCHAR(500));
INSERT INTO p2 VALUES (repeat('a', 200));
ALTER TABLE p2 ALTER COLUMN name TYPE VARCHAR(100);
```

```
ERROR:  value too long for type character varying(100)
```

#### 制約の追加・削除

制約の追加には `ADD CONSTRAINT` 句を使用します。

```SQL
ALTER TABLE customers ADD CONSTRAINT unique_email UNIQUE (email);
```

制約の削除には `DROP CONSTRAINT` 句を使用します。

```SQL
ALTER TABLE orders DROP CONSTRAINT orders_customer_id_fkey;  -- 外部キー制約の削除
ALTER TABLE employees DROP CONSTRAINT employees_email_key;   -- UNIQUE 制約の削除
```

制約名を省略して作った場合、PostgreSQL は `テーブル名_列名_fkey` `テーブル名_列名_key` のような名前を自動生成します。削除するときは実際の名前を `\d テーブル名` で確認してください（自動生成の規則は RDBMS によって違います）。

> ここまでの内容は [[00_SQL研修/02_問題/01_SQLとは、CREATE文]] で手を動かして確認します。

## コラム：テーブルの種類（マスタとトラン）

データベースのテーブルは、その役割によって大きく「マスターテーブル」と「トランザクションテーブル」の2種類に分けられます。この2つの関係は、物語における**「登場人物（マスタ）」**と、その登場人物が起こす**「出来事（トラン）」**に例えると非常に分かりやすくなります。

### マスターテーブル（マスタ）

業務の**「主役」**となる、基本的な情報を管理するテーブルです。「顧客」「商品」「社員」といった、いわば**「名詞」**にあたる情報を格納します。

- **静的なデータ:** 一度登録されると、情報はあまり頻繁には変更されません（例：商品の値段が毎日変わることは稀）。
- **正確性の要:** ここに登録された情報が全ての基本となるため、データの重複がなく、常に正確であることが求められます。
- **他のテーブルの参照元:** トランザクションテーブルからは、ID などを通じて常に参照されます。

具体例:

- **顧客マスタ:** 顧客ID、氏名、住所、電話番号など、「お客様」そのものの情報。
- **商品マスタ:** 商品コード、商品名、単価など、「商品」そのものの情報。
- **社員マスタ:** 社員ID、氏名、部署名など、「社員」そのものの情報。

### トランザクションテーブル（トラン）

日々の業務活動によって発生する**「出来事」**や**「履歴」**を記録するためのテーブルです。「誰が」「いつ」「何を」「どうした」といった、いわば**「動詞」**にあたる情報を時系列でどんどん蓄積していきます。

- **動的なデータ:** 日々の業務でデータがどんどん追加されていきます（例：商品の売上記録）。
- **活動の記録:** 時間の経過とともにデータが蓄積されていくのが前提です。
- **マスタを参照して意味を持つ:** このテーブルだけを見ても「顧客ID：1001」が誰なのか分かりません。顧客マスタを参照して初めて「顧客Aさんが」という具体的な意味を持ちます。

具体例:

- **売上トランザクション:** 「**いつ**（販売日時）、**誰が**（顧客ID）、**何を**（商品ID）、**いくつ**（数量）、**いくらで**（販売単価）購入したか」という販売の事実を記録。
- **勤怠トランザクション:** 「**誰が**（社員ID）、**いつ**（日付）、**何時間**（勤務時間）働いたか」という勤務の事実を記録。

### まとめ：2つの関係性

| 項目           | マスターテーブル      | トランザクションテーブル |
| :----------- | :------------ | :----------- |
| **役割**       | **登場人物・名詞**   | **出来事・動詞**   |
| **データの性質**   | 静的（状態・属性）     | 動的（履歴・活動記録）  |
| **更新頻度**     | 低い（変更・修正が中心）  | 高い（追加が中心）    |
| **データの関係**   | 参照される側        | 参照する側        |

このように、**「マスターテーブルに登録された『顧客』や『商品』があって、初めて日々の『売上』というトランザクションが発生する」**と考えると、両者の役割と関係性がより明確になるかと思います。

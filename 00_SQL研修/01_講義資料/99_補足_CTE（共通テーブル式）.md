# 補足：共通テーブル式（CTE）

**`WITH`句で、クエリの途中結果に名前を付ける機能**です。複雑な処理を「①こう集計して、②その結果をこう使う」という段階に分けて書けるようになります。

`WITH`は06章以降の講義資料や解答例にたびたび出てきます。**見かけて気になったらここに戻ってください。** 10章（サブクエリ）以降は、入れ子が深くなったクエリを整理する道具として実際に使います。

---

## 0. この資料で使うテーブル

**08章で作成したテーブルをそのまま使います。** [[00_SQL研修/02_問題/08_結合から使用するテーブル|08_結合から使用するテーブル]] の DDL とテストデータを流してください。

支払金額は`orders`ではなく **`payments.amount`** にあります（1つの注文に対して支払いが複数回ありうるため、表が分かれています → [[08_補足_結合]] §4）。「顧客ごとの購入額」を出すには`customers` → `orders` → `payments`と辿ります。

---

## 1. WITH句の基本

### 1-1. 基本構文

`WITH`の後ろに名前を付けた`SELECT`文を書き、続くメインクエリでその名前を**テーブルのように**使います。

```sql
WITH CTE名 AS (
	-- 途中結果を作るクエリ
	SELECT ...
)
SELECT ...
FROM CTE名;
```

複数定義する場合はカンマでつなぎます。**後ろのCTEから前のCTEを参照できます**（逆はできません）。

```sql
WITH CTE1 AS (
	SELECT ...
),
CTE2 AS (
	SELECT ...
	FROM CTE1        -- 前に定義した CTE1 を参照できる
)
SELECT ...
FROM CTE2;
```

> ⚠️ `WITH`はクエリの**先頭に1回だけ**書きます。2つ目のCTEに`WITH`は付けません（カンマでつなぐ）。

### 1-2. 例：支払合計が1000を超える顧客

「①顧客ごとの支払合計を出す → ②そのうち1000を超える人だけ残す」という2段階の処理です。

```sql
WITH customer_totals AS (
	-- ① 顧客ごとの支払合計を出す
	SELECT
		o.customer_id,
		SUM(p.amount) AS total_amount
	FROM
		orders AS o
		INNER JOIN payments AS p ON o.order_id = p.order_id
	GROUP BY
		o.customer_id
)
-- ② ①の結果を顧客名と結合して絞り込む
SELECT
	c.name,
	t.total_amount
FROM
	customers AS c
	INNER JOIN customer_totals AS t ON c.customer_id = t.customer_id
WHERE
	t.total_amount > 1000
ORDER BY
	t.total_amount DESC;
```

**実行結果:**

```
 name  | total_amount
-------+--------------
 Alice |      2750.00
 Ivy   |      2400.00
 Kevin |      1240.00
 Ellen |      1200.00
(4 rows)
```

`customer_totals`という**名前が付いた途中結果**を先に用意し、メインクエリではそれを1つのテーブルとして扱っています。「集計してから絞り込む」という手順が、そのままSQLの並びになっているのが利点です。

> [!note]- CTE を使わずに書くと
> 同じことは`FROM`句にサブクエリを書いても実現できます（10章）。ただし、途中結果に名前が無く、`FROM`句の中に集計クエリが埋まるので、**外側から読み始めて内側に潜る**読み方を強いられます。CTEは上から下に読めます。

### 1-3. CTEを複数つなぐ

段階が増えても、カンマでつないでいくだけです。

```sql
WITH customer_totals AS (
	-- ① 顧客ごとの支払合計
	SELECT
		o.customer_id,
		SUM(p.amount) AS total_amount
	FROM
		orders AS o
		INNER JOIN payments AS p ON o.order_id = p.order_id
	GROUP BY
		o.customer_id
),
vip AS (
	-- ② ①のうち1000を超える人だけ
	SELECT
		customer_id,
		total_amount
	FROM
		customer_totals
	WHERE
		total_amount > 1000
)
-- ③ ②に顧客名を付ける
SELECT
	c.name,
	v.total_amount
FROM
	customers AS c
	INNER JOIN vip AS v ON c.customer_id = v.customer_id
ORDER BY
	v.total_amount DESC;
```

**実行結果:** §1-2 と同じ4行です。

```
 name  | total_amount
-------+--------------
 Alice |      2750.00
 Ivy   |      2400.00
 Kevin |      1240.00
 Ellen |      1200.00
(4 rows)
```

結果は同じですが、**「集計する」「絞り込む」「名前を付ける」が別の名前に分かれた**ので、どこを直せばよいかが読んで分かります。段階に名前を付けられることがCTEの本質です。

---

## 2. CTE / サブクエリ / ビュー の使い分け

| | サブクエリ（派生表） | ビュー（VIEW） | CTE（`WITH`句） |
| :--- | :--- | :--- | :--- |
| **どこに書くか** | `FROM`句や`WHERE`句の中 | データベースに永続的に定義 | クエリ先頭に一時的に定義 |
| **寿命** | そのクエリ限り | 消すまで残る | そのクエリ限り |
| **同じクエリ内での再利用** | できない（書くたびに再記述） | できる | **できる（名前で何度でも）** |
| **読む向き** | 外→内（入れ子をたどる） | — | **上→下** |
| **向く用途** | 使い捨ての単純な途中結果 | 複数のクエリで共通に使う定番の集合 | 1つのクエリ内での段階分け |

- サブクエリ … 10章
- ビュー … [[99_補足_viewについて]]

### CTEだけができること：同じ途中結果を2回使う

サブクエリとの決定的な差はここです。**一度名前を付ければ、同じクエリの中で何度でも参照できます。**

「支払合計の平均」と「平均を超える人数」を同時に出す例です。`customer_totals`を**3回**参照しています。

```sql
WITH customer_totals AS (
	SELECT
		o.customer_id,
		SUM(p.amount) AS total_amount
	FROM
		orders AS o
		INNER JOIN payments AS p ON o.order_id = p.order_id
	GROUP BY
		o.customer_id
)
SELECT
	(SELECT round(AVG(total_amount), 2) FROM customer_totals) AS avg_amount,
	count(*) AS over_avg
FROM
	customer_totals
WHERE
	total_amount > (SELECT AVG(total_amount) FROM customer_totals);
```

**実行結果:**

```
 avg_amount | over_avg
------------+----------
    1007.78 |        4
(1 row)
```

サブクエリで書くと、**同じ集計クエリを3回書き写す**ことになります。片方だけ直して不整合を起こす典型的な原因です。

---

## 3. パフォーマンス：インライン化とマテリアライズ

CTEは「途中結果を実際に作ってから使う」とは限りません。**実体を作るか、メインクエリに溶け込ませるかは、DBが判断します。**

- **インライン化** … CTEをメインクエリに展開してから最適化する。実体を作らない
- **マテリアライズ** … CTEを先に実行して結果を一時的に持ち、それを読む

`EXPLAIN`（→ 17章）で見分けられます。実体を作ると`CTE Scan`という節点が現れます。

> 🐘 **どこまで通じる話か**
> 「実体を作るか展開するか」という考え方はどのDBにもありますが、**判断の規則と制御の書き方は製品ごとに違います。** 以下は PostgreSQL 12 以降の話です。
>
> - **参照が1回だけなら、インライン化される**（実体を作らない）
> - **2回以上参照すると、マテリアライズされる**（1回だけ実行して使い回す）
> - 再帰CTE（§4）と、`random()`のように呼ぶたび結果が変わる関数を含むCTEは、参照が1回でもインライン化されません
> - `AS MATERIALIZED` / `AS NOT MATERIALIZED` で**明示的に指定できる**。このキーワードは PostgreSQL の拡張で、標準SQLにはありません
>
> ```sql
> -- 実体を作らせない（展開させる）
> WITH t AS NOT MATERIALIZED (SELECT ...) SELECT ... FROM t;
>
> -- 必ず実体を作らせる
> WITH t AS MATERIALIZED (SELECT ...) SELECT ... FROM t;
> ```
>
> PostgreSQL 11 以前は**常にマテリアライズ**されていました。「CTEにすると遅くなる」という古い記事はこの時代の話です。

**重い集計を2回以上使うならマテリアライズが有利**（1回で済む）、**軽いCTEを絞り込みと組み合わせるならインライン化が有利**（`WHERE`をCTEの中に押し込んで最適化できる）という関係です。迷ったら`EXPLAIN`で確かめてください。

---

## 4. 再帰CTE：階層構造を展開する

`WITH RECURSIVE`と書くと、**CTEが自分自身を参照できる**ようになります。組織図や部品表のような、深さが決まっていない階層データを展開できます。

### 4-1. 仕組み：連番で理解する

まず、テーブルを使わない最小の例で動きを掴みます。**1から5までの連番**を作ります。

```sql
WITH RECURSIVE numbers (n) AS (
	-- ① 開始点（非再帰部分）: 1行だけ作る
	SELECT 1

	UNION ALL

	-- ② 繰り返し（再帰部分）: 直前の結果の n に 1 を足す
	SELECT n + 1
	FROM numbers            -- 自分自身を参照する
	WHERE n < 5             -- ここが止まる条件
)
SELECT n FROM numbers ORDER BY n;
```

**実行結果:**

```
 n
---
 1
 2
 3
 4
 5
(5 rows)
```

動き方はこうです。

1. **①が`1`を作る**
2. **②が①の結果（`n=1`）を見て`2`を作る**
3. ②が直前の結果（`n=2`）を見て`3`を作る … これを繰り返す
4. `n=5`のとき`WHERE n < 5`が偽になり、**新しい行が作られなくなって終了**

**「新しい行が1行も作られなくなったら終わる」**のが再帰の停止条件です。②が毎回**直前に増えた分だけ**を見ている点が肝で、全件を見直しているわけではありません。

### 4-2. 階層を展開する

上司・部下の関係を展開します。**この階層データは08章のテーブルには無いので、この資料の中だけで作ります**（`staff`テーブルに上司の列はありません）。

```sql
WITH RECURSIVE org (employee_id, employee_name, manager_id) AS (
	-- この資料だけのサンプル組織図
	VALUES
		(1, 'Alice',   NULL),
		(2, 'Bob',     1),
		(3, 'Charlie', 1),
		(4, 'David',   2),
		(5, 'Eve',     2),
		(6, 'Frank',   3)
),
hierarchy AS (
	-- ① 開始点: 上司がいない人（トップ）
	SELECT
		employee_id,
		employee_name,
		manager_id,
		1 AS level
	FROM
		org
	WHERE
		manager_id IS NULL

	UNION ALL

	-- ② 繰り返し: 直前に見つかった人を上司に持つ部下を探す
	SELECT
		o.employee_id,
		o.employee_name,
		o.manager_id,
		h.level + 1
	FROM
		org AS o
		INNER JOIN hierarchy AS h ON o.manager_id = h.employee_id
)
SELECT
	employee_id,
	employee_name,
	manager_id,
	level
FROM
	hierarchy
ORDER BY
	level,
	employee_id;
```

**実行結果:**

```
 employee_id | employee_name | manager_id | level
-------------+---------------+------------+-------
           1 | Alice         |       NULL |     1
           2 | Bob           |          1 |     2
           3 | Charlie       |          1 |     2
           4 | David         |          2 |     3
           5 | Eve           |          2 |     3
           6 | Frank         |          3 |     3
(6 rows)
```

`level`は`WITH RECURSIVE`が数えてくれるわけではなく、**①で`1`と置き、②で`+1`しているだけ**です。「階層の深さ」のような値は、こうして自分で運ぶ必要があります。

§4-1 と違い、**止まる条件を書いていません。** 部下がいなくなれば②が新しい行を作らなくなるので、それで終わります。データが正しい階層（木）である限り、これで止まります。

### 4-3. 循環参照：深さ制限では答えが壊れる

問題は、データが木になっていないときです。`A → B → C → A`のように**上司の関係が輪になっている**と、②はいつまでも新しい行を作り続けます。

よく「`WHERE level < 10`のように深さの上限を付けて無限ループを防ぐ」と説明されますが、**これは止まるだけで、答えは壊れます。**

```sql
WITH RECURSIVE bad (id, name, boss) AS (
	VALUES (1, 'A', 3), (2, 'B', 1), (3, 'C', 2)   -- A→B→C→A の輪
),
h AS (
	SELECT id, name, boss, 1 AS level FROM bad WHERE id = 1

	UNION ALL

	SELECT b.id, b.name, b.boss, h.level + 1
	FROM bad AS b
	INNER JOIN h ON b.boss = h.id
	WHERE h.level < 10          -- 深さの上限
)
SELECT count(*) AS returned_rows, max(level) AS max_level FROM h;
```

**実行結果:**

```
 returned_rows | max_level
---------------+-----------
            10 |        10
(1 row)
```

**3人しかいないのに10行返ります。** 同じ3人がぐるぐる回って出てきただけです。処理は終わりますが、エラーも警告も出ないまま**嘘の結果**が返ります。

### 循環そのものを検出する：CYCLE句

`CYCLE`句を使うと、**同じ行に2回目に到達した時点で止め、そこに印を付けて**くれます（PostgreSQL 14 以降）。

```sql
WITH RECURSIVE bad (id, name, boss) AS (
	VALUES (1, 'A', 3), (2, 'B', 1), (3, 'C', 2)
),
h AS (
	SELECT id, name, boss, 1 AS level FROM bad WHERE id = 1

	UNION ALL

	SELECT b.id, b.name, b.boss, h.level + 1
	FROM bad AS b
	INNER JOIN h ON b.boss = h.id
) CYCLE id SET is_cycle USING path      -- id が再訪されたら is_cycle を真にする
SELECT id, name, level, is_cycle FROM h ORDER BY level;
```

**実行結果:**

```
 id | name | level | is_cycle
----+------+-------+----------
  1 | A    |     1 | f
  2 | B    |     2 | f
  3 | C    |     3 | f
  1 | A    |     4 | t
(4 rows)
```

10行のゴミではなく**4行**。しかも最後の行に`is_cycle = t`が立ち、**「ここで輪になっている」と分かります。** `WHERE NOT is_cycle`で正常な行だけを取り出せます。

`CYCLE id`の`id`は**「何が同じなら再訪とみなすか」**の指定です。`USING path`で辿った経路を持つ列名を指定します（この列は自動で作られます）。

> ⚠️ **深さの上限は「暴走を止める安全装置」であって、循環対策ではありません。**
> - データが木であると確信できるなら、停止条件は要りません（§4-2）
> - 循環がありうるなら`CYCLE`句を使い、**`is_cycle`で異常を検出する**
> - 深さの上限は、それに加えて掛ける保険として使う

---

## まとめ

| | 覚えること |
| :--- | :--- |
| **CTEの本質** | 途中結果に**名前を付ける**こと。段階が名前で分かれ、上から下に読める |
| **サブクエリとの差** | **同じ途中結果を何度でも参照できる**。書き写して不整合を起こさない |
| **ビューとの差** | CTEはそのクエリ限り。複数クエリで共通に使うならビュー |
| **性能** | 実体を作るか展開するかはDBが決める。制御の書き方は製品ごとに違う（🐘 §3） |
| **再帰** | `WITH RECURSIVE`。**新しい行が作られなくなったら終わる** |
| **循環** | 深さの上限では**答えが壊れる**。`CYCLE`句で検出する |

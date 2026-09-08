# 12章 演習 解答：PL/pgSQL（DOブロック編）

**PostgreSQL 17 で全問実行して確認しています。掲載している出力はすべて実測です。**

> **この演習の前提**
> - 対応する講義は [[12-1_PLpgSQLの基礎とDOブロック|12-1]]／[[12-2_変数とSQLの実行|12-2]]／[[12-3_制御構造|12-3]] です。
> - 使用するテーブルは [[00_SQL研修/02_問題/08_結合から使用するテーブル|08_結合から使用するテーブル]] で作成したもの（8章以降と同じ）です。
> - すべて `DO` ブロックで書きます。結果の確認は `RAISE NOTICE` です。
> - 変数は `v_`、行データを入れる変数は `r_` を付けてください（[[12-1_PLpgSQLの基礎とDOブロック|12-1]] §5）。
> - pgAdmin を使う場合、`RAISE NOTICE` の出力は **「Messages」タブ**に出ます。
> - すべて読み取りだけの `DO` ブロックなので、データは変わりません。**リセットは不要です。**

---

## 問題 1: 会員ランクに応じたメッセージ表示
- **目的**: `SELECT ... INTO` で取った値を `IF ... ELSIF ... ELSE` で分岐させ、NULL のケースを落とさずに扱う。

### 問題:
ブロックの先頭で `v_target_id` に顧客IDを入れ、その顧客の名前（`customers.name`）と会員ランク（`memberships.rank_name`）を取得して、ランクに応じたメッセージを `RAISE NOTICE` で出力する `DO` ブロックを作ってください。

- `Gold` の場合: `ようこそ、プレミアムメンバーの[顧客名] 様`
- `Silver` の場合: `ようこそ、シルバーメンバーの[顧客名] 様`
- `Bronze` の場合: `ようこそ、ブロンズメンバーの[顧客名] 様`
- 会員ランクが設定されていない場合: `ようこそ、[顧客名] 様`
- **その顧客IDが存在しない場合**: `顧客ID [ID] は存在しません`

**確認すること:** `v_target_id` を `1`（Silver）、`4`（Gold）、`3`（ランクなし）、`999`（存在しない）に変えて、4 通りすべてが正しく出ること。

### 解答:
```sql
DO $$
DECLARE
    v_target_id integer := 1;
    v_name      customers.name%TYPE;
    v_rank      text;
BEGIN
    -- 会員ランク未設定の顧客も取りたいので LEFT JOIN
    SELECT c.name, m.rank_name
      INTO v_name, v_rank
      FROM customers c
      LEFT JOIN memberships m ON c.membership_id = m.membership_id
     WHERE c.customer_id = v_target_id;

    IF NOT FOUND THEN
        RAISE NOTICE '顧客ID % は存在しません', v_target_id;
    ELSIF v_rank = 'Gold' THEN
        RAISE NOTICE 'ようこそ、プレミアムメンバーの% 様', v_name;
    ELSIF v_rank = 'Silver' THEN
        RAISE NOTICE 'ようこそ、シルバーメンバーの% 様', v_name;
    ELSIF v_rank = 'Bronze' THEN
        RAISE NOTICE 'ようこそ、ブロンズメンバーの% 様', v_name;
    ELSE
        RAISE NOTICE 'ようこそ、% 様', v_name;
    END IF;
END;
$$;
```


### 期待結果:
`v_target_id` を変えて 4 通り

```
-- v_target_id := 1 （Alice / Silver）
NOTICE:  ようこそ、シルバーメンバーのAlice 様

-- v_target_id := 4 （Diana / Gold）
NOTICE:  ようこそ、プレミアムメンバーのDiana 様

-- v_target_id := 3 （Charlie / ランクなし）
NOTICE:  ようこそ、Charlie 様

-- v_target_id := 999 （存在しない）
NOTICE:  顧客ID 999 は存在しません
```


### 解説:
**この問題で確認すること**
- `DECLARE` で変数を宣言し、`SELECT ... INTO` で値を取得できる（→ [[12-2_変数とSQLの実行|12-2]] §1）
- `IF ... ELSIF ... ELSE` で条件分岐できる（→ [[12-3_制御構造|12-3]] §1）
- **会員ランクが未設定（NULL）のケースを落とさない**

- **`LEFT JOIN` でないと Charlie が取れません。** `INNER JOIN` で書くと `membership_id` が NULL の Charlie は 0 件になり、「存在しません」に落ちます。ここが最初の関門です。
- **`IF NOT FOUND` を `ELSIF` の連鎖の先頭に置く**のが素直な形です。`FOUND` は直前の SQL の結果なので、`SELECT INTO` の直後で判定する必要があります（[[12-2_変数とSQLの実行|12-2]] §3）。
- **`ELSE` を書き忘れると Charlie のケースが黙って消えます。** `v_rank` が NULL のとき `v_rank = 'Gold'` は「偽」ではなく NULL なので、どの `ELSIF` も真になりません（[[12-3_制御構造|12-3]] §1-1）。ここを落とす研修生が多いので、必ず `v_target_id := 3` で確認させてください。

---

## 問題 2: 顧客の存在と注文履歴の確認
- **目的**: `FOUND` と `IF EXISTS (SELECT 1 ...)` を、目的に応じて使い分ける。

### 問題:
ブロックの先頭で `v_target_id` に顧客IDを入れ、次の順で判定してメッセージを出力する `DO` ブロックを作ってください。

1. その顧客が `customers` に**存在しない**場合: `顧客ID [ID] は登録されていません`
2. 存在して、`orders` に注文が**ある**場合: `[顧客名] さんには注文履歴があります`
3. 存在して、注文が**ない**場合: `[顧客名] さんには注文履歴がありません`

**要件:**

- 顧客名の取得と存在確認は `SELECT ... INTO` と `FOUND` で行うこと。
- 注文履歴の有無は `EXISTS` で判定すること（件数は不要なので、変数に受け取らない）。

**確認すること:** `v_target_id` を `6`（Grace・履歴なし）、`1`（Alice・履歴あり）、`999`（存在しない）に変えて、3 通りすべてが正しく出ること。

### 解答:
```sql
DO $$
DECLARE
    v_target_id integer := 6;
    v_name      customers.name%TYPE;
BEGIN
    -- 名前が欲しいので SELECT INTO（存在確認は FOUND で）
    SELECT name INTO v_name FROM customers WHERE customer_id = v_target_id;

    IF NOT FOUND THEN
        RAISE NOTICE '顧客ID % は登録されていません', v_target_id;
    ELSIF EXISTS (SELECT 1 FROM orders WHERE customer_id = v_target_id) THEN
        -- 注文は「あるかないか」だけ知りたいので EXISTS
        RAISE NOTICE '% さんには注文履歴があります', v_name;
    ELSE
        RAISE NOTICE '% さんには注文履歴がありません', v_name;
    END IF;
END;
$$;
```


### 期待結果:
`v_target_id` を変えて 3 通り

```
-- v_target_id := 6 （Grace / 購入履歴なし）
NOTICE:  Grace さんには注文履歴がありません

-- v_target_id := 1 （Alice / 購入履歴あり）
NOTICE:  Alice さんには注文履歴があります

-- v_target_id := 999 （存在しない）
NOTICE:  顧客ID 999 は登録されていません
```


### 解説:
**この問題で確認すること**
- `FOUND` で「取れたかどうか」を判定できる（→ [[12-2_変数とSQLの実行|12-2]] §3）
- `IF EXISTS (SELECT 1 ...)` で存在チェックができる（→ [[12-2_変数とSQLの実行|12-2]] §4）
- 2 つの判定の使い分けができる

- **この問題の狙いは「使い分け」です。** 顧客名は**値が必要**なので `SELECT INTO` + `FOUND`。注文履歴は**あるかないかだけ**なので `EXISTS`。「両方 `SELECT count(*) INTO` で書く」解答が出たら、なぜ `EXISTS` の方が読みやすいかを話してください。
- `RETURN;` で早期に抜ける書き方もありますが、**講義では扱っていない**ので `ELSIF` の連鎖にしています。研修生が `RETURN;` を使ってきたら、動くこと自体は正しいと認めてよいです。
- `EXISTS (SELECT 1 ...)` の `1` は「何を選ぶかは関係ない」という意味です。`SELECT *` でも動きます（10章既習）。

---

## 問題 3: 在庫状況の判定
- **目的**: `%ROWTYPE` で 1 行分をまとめて受け取り、数値の範囲で条件分岐する。

### 問題:
ブロックの先頭で `v_product_id` と `v_warehouse_id` を指定し、`inventory` から該当行を **`inventory%ROWTYPE` の変数に丸ごと**受け取って、在庫数（`stock_quantity`）に応じたメッセージを出力する `DO` ブロックを作ってください。

- 在庫数が 50 以上: `在庫は十分です (在庫数: [在庫数])`
- 在庫数が 10 以上 50 未満: `在庫は残りわずかです (在庫数: [在庫数])`
- 在庫数が 1 以上 10 未満: `在庫が不足しています。発注を検討してください (在庫数: [在庫数])`
- 在庫数が 0: `在庫切れです`
- **該当する在庫行が存在しない場合**: `商品[商品ID] / 倉庫[倉庫ID] の在庫行が存在しません`

**確認すること:** 次の 4 通りで正しく出ること。

| `v_product_id` | `v_warehouse_id` | 期待される分岐 |
|:---|:---|:---|
| 1 | 1 | 在庫は十分です（50） |
| 1 | 2 | 在庫は残りわずかです（10） |
| 9 | 1 | 在庫が不足しています（2） |
| 5 | 2 | 在庫切れです（0） |

### 解答:
```sql
DO $$
DECLARE
    v_product_id   integer := 1;
    v_warehouse_id integer := 1;
    r_inventory    inventory%ROWTYPE;   -- 1行分をまるごと受ける
BEGIN
    SELECT * INTO r_inventory
      FROM inventory
     WHERE product_id = v_product_id AND warehouse_id = v_warehouse_id;

    IF NOT FOUND THEN
        RAISE NOTICE '商品% / 倉庫% の在庫行が存在しません', v_product_id, v_warehouse_id;
    ELSIF r_inventory.stock_quantity >= 50 THEN
        RAISE NOTICE '在庫は十分です (在庫数: %)', r_inventory.stock_quantity;
    ELSIF r_inventory.stock_quantity >= 10 THEN
        RAISE NOTICE '在庫は残りわずかです (在庫数: %)', r_inventory.stock_quantity;
    ELSIF r_inventory.stock_quantity >= 1 THEN
        RAISE NOTICE '在庫が不足しています。発注を検討してください (在庫数: %)', r_inventory.stock_quantity;
    ELSE
        RAISE NOTICE '在庫切れです';
    END IF;
END;
$$;
```


### 期待結果:
4 通り

```
-- 商品1 / 倉庫1（在庫 50）
NOTICE:  在庫は十分です (在庫数: 50)

-- 商品1 / 倉庫2（在庫 10）
NOTICE:  在庫は残りわずかです (在庫数: 10)

-- 商品9 / 倉庫1（在庫 2）
NOTICE:  在庫が不足しています。発注を検討してください (在庫数: 2)

-- 商品5 / 倉庫2（在庫 0）
NOTICE:  在庫切れです
```


### 解説:
**この問題で確認すること**
- `%ROWTYPE` でテーブルの 1 行分をまとめて受け取れる（→ [[12-2_変数とSQLの実行|12-2]] §6）
- 数値の範囲で条件分岐できる（→ [[12-3_制御構造|12-3]] §1）

- **`ELSIF` の順序が重要です。** 上から順に評価されるので、`>= 50` → `>= 10` → `>= 1` → `ELSE` の順に書けば、範囲の上限を書く必要がありません。「10 以上 50 未満」を `>= 10 AND < 50` と書いた解答も正しいですが、順序で解ける方が短いことを見せてください。
- **`SELECT * INTO r_inventory` の `*` が使えるのが `%ROWTYPE` の利点です。** 列を 1 つずつ変数に受ける解答が出たら、`%ROWTYPE` にする意味（テーブル定義が変わっても直さなくてよい）を話してください。
- `inventory` の主キーは `(product_id, warehouse_id)` の複合主キーなので、両方を指定しないと 1 行に絞れません。

---

## 問題 4: 評価ごとのレビュー件数を集計
- **目的**: `FOR i IN 1..5` のカウントループを書き、ループ変数をクエリの条件に使う。

### 問題:
`FOR` ループで 1 から 5 までを回し、各ループでその評価（`reviews.rating`）のレビュー件数を数えて、次の形式で出力する `DO` ブロックを作ってください。

```
評価1: [件数]件
評価2: [件数]件
…
評価5: [件数]件
```

**要件:** ループ変数は `DECLARE` に書かないこと（`FOR` が用意します）。

### 解答:
```sql
DO $$
DECLARE
    v_count integer;
BEGIN
    -- ループ変数 i は DECLARE に書かない（FOR が用意する）
    FOR i IN 1..5 LOOP
        SELECT count(*) INTO v_count FROM reviews WHERE rating = i;
        RAISE NOTICE '評価%: %件', i, v_count;
    END LOOP;
END;
$$;
```


### 期待結果:
```
NOTICE:  評価1: 0件
NOTICE:  評価2: 0件
NOTICE:  評価3: 1件
NOTICE:  評価4: 1件
NOTICE:  評価5: 4件
```


### 解説:
**この問題で確認すること**
- `FOR i IN 1..5` で決まった回数のループを書ける（→ [[12-3_制御構造|12-3]] §2）
- ループ変数をクエリの条件に使える

- **`i` を `DECLARE` に書いてもエラーにはなりません**が、`FOR` が別のループ変数を作るので `DECLARE` した方は使われません。混乱の元なので書かないように指導してください。
- 評価 1・2 が 0 件なのは、初期データにその評価のレビューがないためです。**「0 件の行も出る」のがこの問題の狙い**です。`GROUP BY rating` で集計すると 0 件の評価は行として出てこないので、「1〜5 を必ず全部出す」にはループ（または別の工夫）が要ります。ここが「ループを使う理由がある」数少ない例です。
- `count(*)` は 0 件でも NULL にならず 0 を返すので、この問題では `COALESCE` は不要です。`sum()` との違いを聞かれたら説明してください。

---

## 問題 5: 商品一覧をループで表示
- **目的**: `FOR r_x IN SELECT ... LOOP` でクエリ結果を 1 行ずつ処理する。

### 問題:
`products` と `categories` を結合し、すべての商品について「商品名」「カテゴリ名」「価格」を取得します。`FOR ... IN SELECT ... LOOP` で 1 行ずつ、次の形式で出力する `DO` ブロックを作ってください。

```
商品: [商品名], カテゴリ: [カテゴリ名], 価格: [価格]
```

**要件:**

- 出力順が毎回同じになるように、`product_id` の昇順に並べること。
- 行を受け取る変数は `RECORD` 型で宣言し、名前に `r_` を付けること。

### 解答:
```sql
DO $$
DECLARE
    r_product RECORD;   -- JOIN 結果なので %ROWTYPE ではなく RECORD
BEGIN
    FOR r_product IN
        SELECT p.product_name, c.category_name, p.price
          FROM products p
          JOIN categories c ON p.category_id = c.category_id
         ORDER BY p.product_id
    LOOP
        RAISE NOTICE '商品: %, カテゴリ: %, 価格: %',
            r_product.product_name, r_product.category_name, r_product.price;
    END LOOP;
END;
$$;
```


### 期待結果:
```
NOTICE:  商品: Laptop, カテゴリ: Electronics, 価格: 1200.00
NOTICE:  商品: Smartphone, カテゴリ: Electronics, 価格: 800.00
NOTICE:  商品: Novel, カテゴリ: Books, 価格: 20.00
NOTICE:  商品: T-shirt, カテゴリ: Clothing, 価格: 15.00
NOTICE:  商品: Jacket, カテゴリ: Clothing, 価格: 60.00
NOTICE:  商品: Monitor, カテゴリ: Electronics, 価格: 300.00
NOTICE:  商品: Dining Chair, カテゴリ: Furniture, 価格: 150.00
NOTICE:  商品: Office Chair, カテゴリ: Furniture, 価格: 150.00
NOTICE:  商品: Luxury Sofa, カテゴリ: Furniture, 価格: 800.00
NOTICE:  商品: Technical Book, カテゴリ: Books, 価格: 50.00
NOTICE:  商品: Cap, カテゴリ: Clothing, 価格: 15.00
NOTICE:  商品: Socks, カテゴリ: Clothing, 価格: 5.00
NOTICE:  商品: Headphones, カテゴリ: Electronics, 価格: 150.00
```


### 解説:
**この問題で確認すること**
- `FOR r_x IN SELECT ... LOOP` でクエリの結果を 1 行ずつ処理できる（→ [[12-3_制御構造|12-3]] §3）
- `RECORD` 型の変数で各行のデータにアクセスできる（→ [[12-2_変数とSQLの実行|12-2]] §7）

- **JOIN の結果は `%ROWTYPE` では受けられません。** `products%ROWTYPE` にすると `category_name` が入らないので、`RECORD` が必要です。ここを間違えた研修生には [[12-2_変数とSQLの実行|12-2]] §7-1 の表を見せてください。
- **`ORDER BY` がないと順序が保証されません。** 実際には主キー順で返ることが多いので「なくても動く」と思われがちです。「動く」と「保証されている」は違うことを伝えてください。
- カテゴリ `Office Supplies` は商品がないので出てきません（`INNER JOIN` のため）。**これは仕様どおり**です。「カテゴリを全部出したい」なら `categories` 側からの `LEFT JOIN` になる、という発展の話ができます。

---

## 問題 6: 顧客ごとの注文合計金額
- **目的**: ループとクエリを組み合わせ、合計が 0 になるケースを `COALESCE` で扱う。

### 問題:
すべての顧客（`customers`）についてループし、各顧客の注文合計金額を計算して次の形式で出力する `DO` ブロックを作ってください。

```
顧客名: [顧客名], 注文合計金額: [合計金額]
```

**要件:**

1. 外側のループで `customers` の全顧客を `customer_id` の昇順に処理する。
2. 合計金額は `orderitems.quantity × products.price` の合計とする。
3. 注文ステータス（`orders.status`）が `'Cancelled'` の注文は含めない。
4. **注文が 1 件もない顧客も、合計金額 0 として表示する**（表示を飛ばさない）。

> [!Note]
> この問題は、**わざと「ループの中で毎回集計する」形で書かせています。** これは [[12-3_制御構造|12-3]] §7 で「約 90 倍遅い」と実測した形そのものです。
> 解き終わったら、**同じ結果を `GROUP BY` の 1 文で出す SQL** も書いてみてください。どちらが読みやすいか、なぜ実務では 1 文で書くべきかを体感できます。

### 解答:
```sql
DO $$
DECLARE
    r_customer RECORD;
    v_total    numeric;
BEGIN
    FOR r_customer IN
        SELECT customer_id, name FROM customers ORDER BY customer_id
    LOOP
        -- 注文が無い顧客は sum() が NULL になるので COALESCE で 0 に
        SELECT COALESCE(sum(oi.quantity * p.price), 0)
          INTO v_total
          FROM orders o
          JOIN orderitems oi ON oi.order_id = o.order_id
          JOIN products p    ON p.product_id = oi.product_id
         WHERE o.customer_id = r_customer.customer_id
           AND o.status <> 'Cancelled';

        RAISE NOTICE '顧客名: %, 注文合計金額: %', r_customer.name, v_total;
    END LOOP;
END;
$$;
```


### 期待結果:
```
NOTICE:  顧客名: Alice, 注文合計金額: 2750.00
NOTICE:  顧客名: Bob, 注文合計金額: 1005.00
NOTICE:  顧客名: Charlie, 注文合計金額: 0
NOTICE:  顧客名: Diana, 注文合計金額: 30.00
NOTICE:  顧客名: Ellen, 注文合計金額: 1200.00
NOTICE:  顧客名: Grace, 注文合計金額: 0
NOTICE:  顧客名: Hank, 注文合計金額: 300.00
NOTICE:  顧客名: Ivy, 注文合計金額: 2400.00
NOTICE:  顧客名: Jack, 注文合計金額: 5.00
```

### 解説:
**この問題で確認すること**
- ループとクエリを組み合わせて処理を組み立てられる（→ [[12-3_制御構造|12-3]] §3）
- 合計が 0 になるケースを `COALESCE` で扱える（→ [[12-2_変数とSQLの実行|12-2]] §9）

- **`COALESCE` を落とすと Charlie と Grace が空欄になります。** `sum()` は対象行が 0 件だと NULL を返します。`count()` が 0 を返すのと違うことを、ここで対比させてください（問題 4 との違い）。
- **`'Cancelled'` の除外位置**に注意。Diana（customer_id=4）は Cancelled の注文（order_id=4）と有効な注文（order_id=11）を持っています。除外が効いていれば 30.00 になります。効いていないと 75.00 になるので、**Diana の値が答え合わせのチェックポイント**です。
- **1 文版では `<>` 条件を `LEFT JOIN` の `ON` 側に書く必要があります。** `WHERE` に書くと、注文がない顧客（`o.status` が NULL）が消えて Charlie と Grace が出なくなります。これは 8章の「ON と WHERE の違い」の実例なので、[[00_SQL研修/01_講義資料/08_補足_結合|08_補足_結合]] に戻って確認させると効果的です。
- ループ版は [[12-3_制御構造|12-3]] §7 で測った N+1 の形そのものです。**顧客 9 人なら気になりませんが、10 万人なら 10 万回クエリが飛ぶ**ことを必ず伝えてください。

**参考：同じ結果を 1 文で書く**

問題文の Note で書かせている「`GROUP BY` 版」です。

```sql
SELECT c.name AS 顧客名,
       COALESCE(sum(oi.quantity * p.price), 0) AS 注文合計金額
  FROM customers c
  LEFT JOIN orders o      ON o.customer_id = c.customer_id AND o.status <> 'Cancelled'
  LEFT JOIN orderitems oi ON oi.order_id = o.order_id
  LEFT JOIN products p    ON p.product_id = oi.product_id
 GROUP BY c.customer_id, c.name
 ORDER BY c.customer_id;
```

---

## 補足：つまずいたときに見るところ

| 症状 | 見るところ |
|:---|:---|
| pgAdmin で何も表示されない | 「Messages」タブを見ているか（[[12-1_PLpgSQLの基礎とDOブロック|12-1]] §2-3） |
| `column reference "..." is ambiguous` | 変数名が列名と同じになっている（[[12-1_PLpgSQLの基礎とDOブロック|12-1]] §5） |
| `query has no destination for result data` | 裸の `SELECT` を書いている（[[12-2_変数とSQLの実行|12-2]] §5） |
| `cannot open SELECT INTO query as cursor` | `FOR ... IN` の `SELECT` に `INTO` を書いている（[[12-3_制御構造|12-3]] §3-1） |
| 結果が NULL になる | `SELECT INTO` が 0 件で NULL 上書きされている（[[12-2_変数とSQLの実行|12-2]] §2-1） |

### 解説:

**過去にあったエラーの全リスト**

| エラー / 症状 | 原因と対処 |
|:---|:---|
| `cannot open SELECT INTO query as cursor` | `FOR ... IN` の `IN` の後の `SELECT` に `INTO` を書いている。`FOR` の直後のレコード変数が受け取り先なので `INTO` は不要（[[12-3_制御構造|12-3]] §3-1） |
| `column reference "customer_id" is ambiguous` | 変数名を列名と同じにしている。`v_` を付ける（[[12-1_PLpgSQLの基礎とDOブロック|12-1]] §5） |
| `query has no destination for result data` | 裸の `SELECT` を書いている。結果を捨てるなら `PERFORM`（[[12-2_変数とSQLの実行|12-2]] §5） |
| pgAdmin で何も表示されない | 「Data Output」タブを見ている。`RAISE NOTICE` は「Messages」タブ（[[12-1_PLpgSQLの基礎とDOブロック|12-1]] §2-3） |
| 問題 1 で Charlie が「存在しません」になる | `INNER JOIN` で書いている。`membership_id` が NULL なので `LEFT JOIN` が必要 |
| 問題 1 で Charlie のとき何も出ない | `ELSE` を書いていない。NULL はどの `ELSIF` にも当てはまらない（[[12-3_制御構造|12-3]] §1-1） |
| 問題 6 で Charlie / Grace が空欄 | `sum()` が NULL を返している。`COALESCE(..., 0)` が必要 |
| 問題 6 で Diana が 75.00 になる | `'Cancelled'` の除外が効いていない |

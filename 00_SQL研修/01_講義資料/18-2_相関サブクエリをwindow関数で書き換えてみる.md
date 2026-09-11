# 相関サブクエリ vs ウィンドウ関数：モダンな書き換えガイド

かつて相関サブクエリで行われていた処理の多くは、現在では**ウィンドウ関数**でより簡潔・高速に記述できるようになりました。しかし、すべてのケースで置き換えるべきわけではありません。3つの思考パターンからその使い分けを整理します。

---

## パターン1：存在チェック (`WHERE EXISTS`)
**【結論】無理にウィンドウ関数に置き換えず、`EXISTS` を使うべき**

*   **目的**: 別テーブルにデータがあるかどうかを判定する。
*   **相関サブクエリの利点**: `EXISTS` は「条件に合うものが1つ見つかった時点でスキャンを止める（セミジョイン）」ため、非常に効率的です。
*   **ウィンドウ関数の弱点**: ウィンドウ関数を使うには一度 `JOIN` して全行を結合する必要があり、データ量が多いと無駄な計算コストがかかります。

**❌ 置き換えをおすすめしない例**（無理にウィンドウ関数を使うと複雑化する）
```sql
-- 相関サブクエリ EXISTS（シンプルかつ高速）
SELECT
	name
FROM
	customers c
WHERE
	EXISTS (
		SELECT
			1
		FROM
			orders o
		WHERE
			o.customer_id = c.customer_id
	);

-- ウィンドウ関数（JOINが必要になり、DISTINCTしないと行が増える可能性がある）
SELECT DISTINCT
	name
FROM
	(
		SELECT
			c.name,
			COUNT(o.order_id) OVER (
				PARTITION BY
					c.customer_id
			) AS cnt
		FROM
			customers c
			LEFT JOIN orders o ON c.customer_id = o.customer_id
	) t
WHERE
	cnt > 0;
```

---

## パターン2：グループ内比較・Top-N分析 (`WHERE` + 比較)
**【結論】ウィンドウ関数が圧勝。可読性と柔軟性が格段に向上する**

*   **目的**: 「カテゴリごとの最高値」や「上位3件」などの抽出。
*   **相関サブクエリの欠点**: カテゴリごとに何度も最大値を計算し直すため、パフォーマンスが低下しやすい。
*   **ウィンドウ関数の利点**: データを一度ソートするだけで順位が確定するため高速。また、`RANK()`、`DENSE_RANK()`、`ROW_NUMBER()` を使い分けることで「同率順位をどう扱うか」を簡単に制御できる。

**✅ ウィンドウ関数によるモダンな書き換え（Top-N分析）**
```sql
-- 相関サブクエリ (WHERE + 比較演算子)
SELECT
	p1.product_name,
	p1.price,
	p1.category_id
FROM
	products AS p1
WHERE
	p1.price = (
		SELECT
			MAX(p2.price)
		FROM
			products AS p2
		WHERE
			p2.category_id = p1.category_id
	);

-- ウィンドウ関数 各カテゴリの最高価格商品を取得
SELECT
	product_name,
	price,
	category_id
FROM
	(
		SELECT
			*,
			RANK() OVER (
				PARTITION BY
					category_id
				ORDER BY
					price DESC
			) AS rnk
		FROM
			products
	) sub
WHERE
	rnk = 1;
```
*   **メリット**: 「2番目に高い商品」を取りたければ `rnk = 2` に変えるだけ。相関サブクエリでは2番目の値を取得するのは非常に困難です。

---

## パターン3：文脈情報の付加 (`SELECT` + スカラーサブクエリ)
**【結論】ウィンドウ関数が圧勝。圧倒的に読みやすく、複数列の追加も容易**

*   **目的**: 各行に「そのカテゴリの平均」や「全体の合計」を並記する。
*   **相関サブクエリの欠点**: 平均、合計、最大値を並記したい場合、その数だけサブクエリを書く必要があり、コードが肥大化する。
*   **ウィンドウ関数の利点**: 1つの `SELECT` 内に複数のウィンドウ関数を並べても、実行効率が落ちにくい。

**✅ ウィンドウ関数によるモダンな書き換え（統計情報の併記）**
```sql
-- 相関サブクエリ （SELECT + スカラーサブクエリ）
SELECT
	p.product_name,
	p.price,
	ROUND(
		(
			SELECT
				AVG(price)
			FROM
				products
			WHERE
				category_id = p.category_id
		)
	) AS avg_cat_price,
	(
		SELECT
			SUM(price)
		FROM
			products
		WHERE
			category_id = p.category_id
	) AS sum_cat_price,
	ROUND(
		(
			SELECT
				AVG(price)
			FROM
				products
		)
	) AS global_avg_price
FROM
	products AS p;

-- ウィンドウ関数
SELECT
	product_name,
	price,
	-- カテゴリ平均、カテゴリ合計、全体平均を一度に取得
	ROUND(
		AVG(price) OVER (
			PARTITION BY
				category_id
		)
	) AS avg_cat_price,
	SUM(price) OVER (
		PARTITION BY
			category_id
	) AS sum_cat_price,
	ROUND(AVG(price) OVER ()) AS global_avg_price
FROM
	products;
```
*   **メリット**: スカラーサブクエリだと3つもサブクエリを書く必要がありますが、ウィンドウ関数なら数行追加するだけで済み、スキャン回数も最小限に抑えられます。

---

## 比較表：どちらを使うべきか？

| 特徴 | 相関サブクエリ | ウィンドウ関数 |
| :--- | :--- | :--- |
| **実行効率** | 低い（1行ごとにクエリが走るイメージ） | **高い**（一括処理・ソートで完結） |
| **コードの短さ** | 肥大化しやすい | **簡潔** |
| **行数変化** | 変化しない | 変化しない |
| **別テーブル判定** | **得意 (`EXISTS`)** | 不向き（JOINが必要） |
| **ランキング・順位** | 非常に困難 | **大得意** |
| **複数項目の集計** | 列の数だけクエリが必要 | **1つのSELECTで完結** |

### 結論
現代においては、**「外部テーブルとの存在チェックには `EXISTS` を使い、それ以外の同一データセット内での比較・集計・ランキングはすべてウィンドウ関数を使う」**と整理するといいかと思います。

なお、上の「実行効率」は目安です。PostgreSQL は相関サブクエリを内部で結合に書き換えることがあり、常に表のとおりになるとは限りません。**気になったら [[17-2_実践_EXPLAINの読み方]] のやり方で、実際の実行計画を見比べてください。**

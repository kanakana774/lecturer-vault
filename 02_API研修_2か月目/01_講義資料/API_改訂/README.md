# API_改訂 — 2か月目 API講義の作り直し

**既存の `API/` とは別に、ゼロから書き直している途中の資料。** 完成したら
`todo-app-api-docs/05.講義資料/01.講義/` の `01`〜`03` をこの `01`〜`06` で置き換え、`07` を `04.post処理を作ってみよう.md` と差し替える（研修生に配布されるのはそちら）。

- **`API/` は触らない。** 現行の講義はそちらで回っている
- **移植先の都合**: docs では画像が相対パス参照（`../.attachments/...`）になる。
  この vault では Obsidian の basename 解決に任せているので、移植時に書き換える

---

## 方針

| | |
| :--- | :--- |
| 枠組み | **レイヤードアーキテクチャに一本化**。MVC は出さない（画面を作らないので繋がらない） |
| 範囲 | `01`〜`06` は課題着手前の事前知識フェーズ（講義2回分。`01`〜`03` が1回目、`04`〜`06` が2回目）。`07` は tag 課題の POST を書くときの手本 |
| 到達点 | 各章の冒頭に「この章でできるようになること」を置く |

## 構成

| 回 | ファイル | 中身 |
| :--- | :--- | :--- |
| 1回目 | `01_Webアプリケーションの仕組み.md` | クライアント/サーバ、HTML/CSS/JS、静的と動的、SPA |
| | `02_APIとWebAPI.md` | API とは → Web API → 公開APIを叩くデモ |
| | `03_HTTPプロトコル.md` | リクエスト/レスポンスの構造、URL、パラメータ3種、ステータスコード、JSON |
| 2回目 | `04_課題で作るものの全体像.md` | 3クラス＋Form/Entity と、リクエスト1本が流れる図 |
| | `05_なぜクラスを分けるのか.md` | アーキテクチャ、レイヤード3層、凝集度、結合度、分けるコスト |
| | `06_フレームワークとORマッパー.md` | Spring Boot、MyBatis、起動シーケンスとDI |
| 課題 | `07_POST処理を作ってみよう.md` | スポーツ登録を例に、Form〜Mapper XML の書き方。tag に置き換えて書かせる |
| | `08_1件取得と例外.md` | パスパラメータ、例外を自分で投げる、社長・上司・部下で「誰が投げて誰が受け止めるか」 |

**「何を作るか（04）→ なぜその形か（05）→ 何がそれを動かすか（06）」** の一本道にする。
DI は 05 の「誰かが外から渡す必要がある」を 06 で回収する形にし、二重説明を避ける。

## この改訂で扱わないもの

次の2つは事前知識フェーズではなく、実装の講義で扱う。**ここには書かない。**

- **トランザクション** … todo課題2の前。2テーブル操作のコードと合わせて説明する
- **例外ハンドリング（GlobalErrorController）** … 1件GETの回。自分で例外を投げる場面と合わせて説明する

レビュー観点（N+1・DB制約・Service の責務など）も講義には載せない。レビューで個別に扱う。

## 実挙動の裏取り

`06` の起動シーケンスは、`review/todo-app-api` の `origin/answer-sample` を実際に起動して
DEBUG ログで確認した内容に基づく（2026-09-17、Spring Boot 3.4.1 / Java 21 /
MyBatis Spring Boot Starter 3.0.4 / PostgreSQL 17.5）。**推測で書かない。**

## `07` の罠（講師用）

**`07` はわざと、写しただけでは動かないように作ってある。** 手本が無くなる GET・PUT・DELETE の前に、
エラーを読んで自分で直す（または質問して直す）経験を1回させるため。研修生には「罠がある」ことだけを
本文冒頭で伝え、中身は書いていない。**この節は docs に移植しない。**

| # | 罠 | 仕込み方 | 踏むとどうなるか（実測） | 気づかせたいこと |
| :--- | :--- | :--- | :--- | :--- |
| 1 | **`version` を入れていない** | テーブル定義で `VERSION` は NOT NULL と見せ、`§1-2` の期待値も 0 と書いたうえで、Controller・Service のどこにも `setVersion` が無い | 500。`Caused by: org.postgresql.util.PSQLException: ERROR: null value in column "version" of relation "sport" violates not-null constraint` ／ `詳細: Failing row contains (1, サッカー, 11, null).` | 一番下の `Caused by:` を読む。どこで入れるべきか（業務の既定値なので Service。`0` は定数に＝マジックナンバー禁止） |
| 2 | **文字数の上限** | 例は `@Size(max = 20)`。tag の上限（30）は本文に書かず「API 設計書から読み取れ」とだけ書いた | 20 のまま写すと、21〜30 文字の tag が 400 になる。§8 の境目テストで気づく | 数字は設計書から取る |
| 3 | 名前の置き換え漏れ（仕込んではいないが、ほぼ全員が踏む） | `keyProperty="sportId"` を tag 側で直し忘れる／Entity のフィールド名と食い違う | 500。`No setter found for the keyProperty 'tagId' in '...SportEntity'.`（§9-2 の読み方の例にこのログを使っている） | ③ のメッセージにフィールド名とクラス名が出る |
| 4 | 同上 | XML の `namespace` と Mapper インターフェースのパッケージが食い違う／XML を `mapper-locations` の外に置く | 500。`BindingException: Invalid bound statement (not found): jp.aevic.todo.mapper.sport.SportMapper.insert` | XML とインターフェースの対応づけ（namespace + id）。置き場所は `application.properties` で決まっている |

- **罠 1 を踏まずに通った場合**は、答えのコードと同じく Controller で `0` を入れている可能性がある。
  誤りではないが、「なぜそこか」を聞いて Service との違いを考えさせる
- `int` で受けると `@NotNull` が効かない件（C-19）は、エラーが出ず自力では気づけないので罠にせず、
  本文 §3 に ⚠️ で書いた
- Form の getter / setter を「省略」のまま書かないと、コンパイルエラーになるだけ（罠にはならない）

### 実測の条件

`07` のコード例は `origin/develop`（雛形）に組み込み、使い捨て DB（`SPORT` テーブルのみ）で起動して
確認した（2026-09-30）。

- 罠 1 を直した状態（Service で `setVersion` する）で、正常系が 201 と `Location: .../sports/{id}`、
  `name` 欠落・空白・21 文字と `playerCount` 欠落が 400、DB に `version = 0` で入る
- 罠 1・3・4 は上の表のとおり 500。Postman には原因の出ない汎用メッセージしか返らない（§9-1）
- 1 回の例外で出るログは約 165 行、`Caused by:` は 2 段
- `int` で受けると `@NotNull` が効かない件は `review/_review-kit/curriculum-feedback/todo-app-api.md` C-19 の実測に基づく

## `08` の元ネタと裏取り

- 元ネタ: `API/API研修説明用資料.canvas` の「一件GET」ノードと、`_general/_excalidraw/Drawing 2026-06-04 10.09.11.excalidraw.md`
  の社長・上司・部下の図（同じファイルにメモリの図も同居しているので、そのまま埋め込まず本文にコードで起こした）
- §5-2 の図は `_excalidraw/08_作図_例外はエスカレーション.excalidraw.md` に新しく描いた（会社とアプリの2列）。docs に移すときは PNG に書き出す
- canvas の `@PathVariable String` + `Integer.parseInt` は、`Integer` で受ける形に改めた
- 役の割り当て（部下＝Mapper／上司＝Service／社長＝`GlobalErrorController`、Controller は素通し）は
  canvas・図に明記が無く、この資料で決めたもの
- 実測（2026-09-30、`origin/develop` に組み込み）: `GET /sports/1` → 200 と JSON、`/sports/999` → 404
  `notFound.resource`、`/sports/abc` → 500（C-16）。存在チェックを外すと 200・`Content-Length: 0`。
  404 のとき `"ERROR" dispatch for GET "/error"` が出て `GlobalErrorController` が受け止めることをログで確認

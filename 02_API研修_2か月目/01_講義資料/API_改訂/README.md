# API_改訂 — 2か月目 API講義の作り直し

**既存の `API/` とは別に、ゼロから書き直している途中の資料。** 完成したら
`todo-app-api-docs/05.講義資料/01.講義/` の `01`〜`03` をこの `01`〜`06` で置き換え、`07` を `04.post処理を作ってみよう.md` と差し替える（研修生に配布されるのはそちら）。

**反映状況（2026-09-30）**: `todo-app-api-docs` の `docs/lecture-revise-api` ブランチに push 済み（PR 未作成）。
docs 側は `01.`〜`09.` がここの 01〜09、`10.トランザクション` `11.DI` は旧版のまま、画像は `05.講義資料/.attachments/講義/`。
ここを直したら docs にも同じ変更を入れる（ファイル名の `_` を `.` に、画像パスを `../.attachments/講義/` に置き換えてコピー）

- **`API/` は触らない。** 現行の講義はそちらで回っている
- **図と画像は GitHub でも表示できる形にしてある。** 本文は `![説明|幅](_attachments/xxx.png)` の相対パスで埋め込み、
  Mermaid と Obsidian の `![[...]]` は使わない。画像はこのフォルダの `_attachments/` にまとめ、図の元は `_excalidraw/` に置く
  （図を直したら PNG を書き出し直す。`API/_attachments/` から持ってきた画像は、basename が重ならないよう名前を付け直したコピー）

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
| | `09_更新と排他制御.md` | version の正体、更新消失、悲観／楽観、TOCTOU をデバッガで見せる、楽観ロックの実装。削除は同じ考え方として1節だけ |

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
- §5-1 の図は `_excalidraw/08_作図_例外はエスカレーション.excalidraw.md` に新しく描いた（社長・上司・部下と命令／報告の矢印に、各自の try-catch・if のコードを添える。アプリの層は載せない）。本文には書き出した `_attachments/08_作図_例外はエスカレーション.png` を載せている
- canvas の `@PathVariable String` + `Integer.parseInt` は、`Integer` で受ける形に改めた
- 図は会社の例（呼び出し＝命令、throw＝報告）だけで描き、層は載せていない。人の役とクラスを1対1で重ねると混乱するため、
  §5-2 でも人の役とは対応させず、各層が例外について何をするかだけを書いた
- 実測（2026-09-30、`origin/develop` に組み込み）: `GET /sports/1` → 200 と JSON、`/sports/999` → 404
  `notFound.resource`、`/sports/abc` → 500（C-16）。存在チェックを外すと 200・`Content-Length: 0`。
  404 のとき `"ERROR" dispatch for GET "/error"` が出て `GlobalErrorController` が受け止めることをログで確認

## `09` の元ネタと裏取り

- 元ネタ: canvas の「API 3回目」ノード（Java で `version` を比べてから更新する `updateTag` と「どこが問題でしょうか？」）、
  `API/05.排他制御.md`、`API/_excalidraw/98_作図_楽観ロックの具体例.excalidraw.md`（書き出して `_attachments/09_作図_更新消失.png` として §3 に載せた）
- **§5 の書き方は「悪い例」として出していない。** TOCTOU を考えるきっかけとして素直な実装を置き、§6 で止めて見せ、
  §7 で1つの答え、§10 で答えを書かない問い（存在確認と UPDATE の間の削除＝C-18）を残す構成にした
- 実測（2026-09-30、`origin/develop` に組み込み、デバッガの代わりに確認と更新の間に 3 秒の sleep）:
  - §5 の形: A・B を同時に送ると両方 204、DB は `サッカーB|7|2`（A の更新が消える）
  - §7 の形: 同時に送ると A 204 / B 409、DB は `サッカーA|11|1`。順に送っても B は 409
  - 条件付き UPDATE の同時実行（psql 2 本）: 後から来た UPDATE は先のコミットまで約 3 秒待たされ、`UPDATE 0`
  - §10 の隙: 存在確認の後、UPDATE までに行を DELETE すると **409** が返る（本来は 404）
  - `version` 欠落で 400、存在しない ID で 404

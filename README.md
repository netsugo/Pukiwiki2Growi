# Pukiwiki2growi

[![Build Status](https://travis-ci.com/netsugo/pukiwiki2growi.svg?branch=master)](https://travis-ci.com/netsugo/pukiwiki2growi)
[![Maintainability](https://api.codeclimate.com/v1/badges/c11f448eb2c23bf2d95f/maintainability)](https://codeclimate.com/github/netsugo/pukiwiki2growi/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/c11f448eb2c23bf2d95f/test_coverage)](https://codeclimate.com/github/netsugo/pukiwiki2growi/test_coverage)

PukiWiki から GROWI へ移行するためのツールです。

## Features

- Regexと並列化による高速変換
- ほとんどのPukiWiki要素をサポート
- 添付ファイルをサポート

## Requirements

- 移行先の GROWI が起動しており、添付ファイルをアップロード可能な状態になっていること。
- Ruby, Bundle があらかじめインストールされていること。

## Configuration

[config.yml](config.yml) を開き、以下の項目を設定します。

- （必須）PUKIWIKI_DIR: PukiWiki がインストールされているディレクトリ
- （必須）URL: GROWI の URL
- （必須）API_TOKEN: GROWI の API トークン
- TOP_PAGE: 移行時のトップページを指定します。
    - `/` を指定すると、GROWI のトップページは PukiWiki の `FrontPage` の内容に上書きされます。
    - `/migrate` と指定した場合、 PukiWikiの `example` のページは `/migrate/example` に移行されます。 `/migrate` の内容は PukiWiki の `FrontPage` の内容となります。 
- LOG_ROOT: ログの出力先を指定します。デフォルトでは、`log/` 以下に出力されます。
- ENABLE_PROGRESS: `false` にすると、進捗バーの表示を無効化します。
- ENABLE_LOG: `false` にすると、ログの出力を無効化します。
- BLACKLIST: ロード時に除外するページを指定します。

## Usage

```bash
bundle install
rake app
```

実行すると、 `log/` 以下に json 形式のログが保存されます。

## サポートする要素

- [FormattingRules - PukiWiki](https://pukiwiki.osdn.jp/?FormattingRules)

### ブロック要素

※がついている要素はサポートしていない項目があります。

- 段落
- 引用文
- リスト
    - UL/OL/DL
- 整形済みテキスト
- 表組み（※）
- CSV形式の表組み（※）
- 見出し
- 目次
    - GROWI で toc プラグインを導入している場合に限る
- 左寄せ・センタリング・右寄せ
- 水平線
- 行間明け
- 添付ファイル・画像の貼り付け（※）
- shadowheader
    - 単純な見出しへの変換

以下の要素、およびその他記載されていない要素やプラグインはサポート対象外です。

- 表組み
    - 左寄せ/中央寄せ/右寄せ
    - 文字色/背景色
    - セル幅
    - ヘッダ/フッダ行
    - 書式指定行
    - colspan/rowspan
- CSV 形式の表組み
    - 左寄せ/中央寄せ/右寄せ
    - colspan
- 添付ファイル
    - 他ページへの添付ファイルの参照
    - 位置指定（left/center/right）
    - 枠指定（wrap/nowrap）
    - 回り込み（around）

### インライン要素

- 文字列
- 改行
- 強調・斜体
- 文字サイズ
- 文字色
- ルビ構造
- 取消線
- 注釈
- 添付ファイル・画像の貼り付け（※）
- ページ名 (※)
- InterWiki (※）
- リンク
- エイリアス (※）
- タブコード
- 文字参照文字
- 数値参照文字
- ls/ls2
    - GROWI で lsx プラグインを導入している場合に限る

以下の要素、およびその他記載されていない要素やプラグインはサポート対象外です。

- WikiName
- 添付ファイル・画像の貼り付け: [ブロック要素](#ブロック要素)を参照
- ページ名/InterWiki/エイリアス
    - アンカーの指定
- ページ名置換文字
- 日付置換文字

### その他

- コメント行

## 表について

markdownではcolspanやrowspanがサポートされていません。そのため、pukiwikiでcolspanやrowspanが使われている表をmarkdownに変換すると表が崩れる場合があります。

移行時には次の指標を参考にしながら、markdownに変換しても表が崩れないように修正するか、変換した後に修正します。

### 同じ要素の結合

以下のようなPukiWikiの表を想定します。このとき、x1が繰り返し出ているのでcolspanで結合した時を考えています。

```
-------------
|x1     |x3 |
-------------
|y1 |y2 |y3 |
-------------
```

markdownでは次のように表示されます。(csv colspanを使った場合)

```
-------------
|x1 |== |x3 |
-------------
|y1 |y2 |y3 |
-------------
```

この問題は同じ要素も繰り返し記述することで回避できます。

```
-------------
|x1 |x1 |x3 |
-------------
|y1 |y2 |y3 |
-------------
```

### 途中に中/小見出し代わりの文が挿入されている

以下のようなPukiWikiの表を想定します。

```
------------------
|x1      |x2 |x3 |
-------------
|見出し文        |
-------------
|y1      |y2 |y3 |
------------------
```

markdownでは次のように表示されます。(csv colspanを使った場合)

```
------------------
|x1         |x2 |x3 |
------------------
|見出し文   |== |== |
------------------
|y1         |y2 |y3 |
------------------
```

この場合、表の構造に問題がある可能性があります。この問題は、`見出し文`を基準にして表を分割することで回避できます。

```
-------------
|x1 |x2 |x3 |
-------------

見出し文

-------------
|y1 |y2 |y3 |
-------------
```

## Contributing

不具合報告やPRなど随時歓迎しています。

## Inspired by

- [ryu-sato/conv-pkwk2growi](https://github.com/ryu-sato/conv-pkwk2growi)
- [sunaot/pukiwiki2md](https://github.com/sunaot/pukiwiki2md)
- [PukiWiki](https://pukiwiki.osdn.jp/)
- [GROWI](https://growi.org/)

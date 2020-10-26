# Pukiwiki2growi

[![Build Status](https://travis-ci.com/netsugo/pukiwiki2growi.svg?branch=master)](https://travis-ci.com/netsugo/pukiwiki2growi)
[![Maintainability](https://api.codeclimate.com/v1/badges/c11f448eb2c23bf2d95f/maintainability)](https://codeclimate.com/github/netsugo/pukiwiki2growi/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/c11f448eb2c23bf2d95f/test_coverage)](https://codeclimate.com/github/netsugo/pukiwiki2growi/test_coverage)

PukiWiki から GROWI へ移行するためのツールです。

## Requirements

- 移行先の GROWI が起動しており、添付ファイルをアップロード可能な状態になっていること。
- Ruby, Bundle があらかじめインストールされていること。

## Installation

1. このリポジトリをクローンします。
1. `bundle install` でライブラリをインストールします。

```bash
# HTTPS
git clone https://github.com/netsugo/pukiwiki2growi.git
bundle install
```

or

```bash
# SSH
git clone git@github.com:netsugo/pukiwiki2growi.git
bundle install
```

## Configuration

[config.yml](config.yml) を開き、以下の項目を設定します。

- （必須）PUKIWIKI_DIR: PukiWiki がインストールされているディレクトリ
- （必須）URL: GROWI の URL
- （必須）API_TOKEN: GROWI の API トークン
- TOP_PAGE: 移行時のトップページを指定します。
    - `/` を指定すると、GROWI のデフォルトトップページは PukiWiki の `FrontPage` の内容に上書きされます。
    - `/migrate` と指定した場合、 PukiWikiの `example` のページは `/migrate/example` に移行されます。 `/migrate` の内容は PukiWiki の `FrontPage` の内容となります。 
- LOG_ROOT: ログの出力先を指定します。デフォルトでは、`log/` 以下に出力されます。
- ENABLE_PROGRESS: `false` にすると、進捗バーの表示を無効化します。
- ENABLE_LOG: `false` にすると、ログの出力を無効化します。

## Usage

[migrate.rb](migrate.rb) を実行します。

```bash
bundle install
ruby ./migrate.rb
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

## Contributing

不具合報告やPRなど随時歓迎しています。

## Inspired by

- [ryu-sato/conv-pkwk2growi](https://github.com/ryu-sato/conv-pkwk2growi)
- [sunaot/pukiwiki2md](https://github.com/sunaot/pukiwiki2md)

## TODO

UTF8 ver のサポート

BEGIN TRANSACTION;

CREATE TABLE prices (
  id         SERIAL,
  url        TEXT           NOT NULL,
  scraped_at TIMESTAMPTZ    NOT NULL,
  price      NUMERIC(10, 2) NOT NULL
);

CREATE INDEX index_prices_on_url_and_sraped_at
  ON prices (url, scraped_at);

COMMIT TRANSACTION;

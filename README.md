# jomatracker

Tracks the price of a single watch on Jomashop. Stores data points to Postgres
and sends an e-mail if the newest price point is lower than the last.

## Local Deploy

``` sh
createdb jomatracker
psql jomatracker < db/structure.sql
cp .env.sample .env
# fill in values in .env
bin/scrape
```

## Heroku Deploy

``` sh
heroku create jomatracker
heroku addons:add mailgun
heroku addons:add postgresql
git push heroku master
heroku config:set NOTIFY_EMAIL=... WATCH_URL=...
heroku run 'psql $DATABASE_URL < db/stucture.sql'
heroku run bundle exec bin/scrape
heroku addons:open scheduler
```

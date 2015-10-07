require "excon"
require "uri"

module Jomatracker
  # Scrapes a single link containing information about a watch. Stores the
  # data point and time of scrape to the database (at `DB`). If the price is
  # lower than the previous data point, notifies the address at `notify_email`.
  #
  # Expects a database connection to have already been established as `DB`.
  class Scraper
    def initialize(mailgun_api_key:, mailgun_domain:, notify_email:, watch_url:)
      self.mailgun_api_key = mailgun_api_key
      self.mailgun_domain  = mailgun_domain
      self.notify_email    = notify_email
      self.watch_url       = watch_url
    end

    def run
      price = fetch_price

      if !price
        log "Couldn't fetch/parse price! Returning ..."
        return
      end

      log "Fetched price", price: price

      if last_price = fetch_last_price
        last_price = last_price.to_f
        log "Fetched last price", price: last_price
      end

      insert_price(price)

      if !last_price || price <= last_price
        notify(price, last_price)
      end
    end

    private

    attr_accessor :mailgun_api_key
    attr_accessor :mailgun_domain
    attr_accessor :notify_email
    attr_accessor :watch_url

    def fetch_last_price
      DB[:prices].filter("url = ?", watch_url).reverse_order(:scraped_at).
        get(:price)
    end

    def fetch_price
      log "Fetching watch URL", url: watch_url
      resp = Excon.get(watch_url, expects: 200)

      # TODO: needs to be more robust
      if resp.body =~ %r{<meta itemprop="price" content="(.*)">}
        # will be of the form "$7,150.00"
        $1.gsub(/^\$/, '').gsub(',', '').to_f
      else
        nil
      end
    rescue Excon::Errors::Error
      log "Request failed", error: $!.message
      nil
    end

    def insert_price(price)
      log "Storing price to database", price: price
      DB[:prices].insert(
        price:      price,
        scraped_at: Time.now,
        url:        watch_url
      )
    end

    def notify(price, last_price)
      log "Price is lower than the last data point; notifying",
        email: notify_email

      message = "Lower price on watch; now $#{price} (was: $#{last_price})"

      resp = Excon.post(
        "https://api:#{mailgun_api_key}@api.mailgun.net/v2/#{mailgun_domain}/messages",
        body: URI.encode_www_form(
          from:    notify_email,
          to:      notify_email,
          subject: message,
          text:    message,
        ),
        headers: {
          "Content-Type" => "application/x-www-form-urlencoded",
        },
        expects: 200
      )
    rescue Excon::Errors::HTTPStatusError
      log "Notification failed", error: $!.message, body: $!.response.body
    rescue Excon::Errors::Error
      log "Notification failed", error: $!.message
    end

    def log(message, data = {})
      # make sure that message is printed first
      data = {
        msg: message,
      }.merge(data)
      $stdout.puts data.map { |k, v|
        v = %{"#{v}"} if v.to_s.include?(" ")
        v = v.to_s.gsub(/[\n\r]/, '')
        "#{k}=#{v}"
      }.join(" ")
    end
  end
end

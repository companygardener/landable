class AddLocalSchema < ActiveRecord::Migration
  def up
    return unless Landable.configuration.local_enabled

    local    = "#{Landable.configuration.database_schema_prefix}landable_local"
    landable = "#{Landable.configuration.database_schema_prefix}landable"

    execute <<-SQL
      CREATE SCHEMA #{local};
      CREATE EXTENSION IF NOT EXISTS postgis;
      CREATE EXTENSION IF NOT EXISTS postgis_topology;
      CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
      CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
    SQL

    create_lookup_table :location_types,  schema: local, small: true
    create_lookup_table :list_types,      schema: local, small: true
    create_lookup_table :payment_methods, schema: local, small: true

    create_lookup_table :categories, schema: local do |t|
      t.string :yext_mapping
      t.string :google_mapping
    end

    Landable::Local::LocationType.lookup.seed   'Brick and Mortar', 'Service Area', 'Home Based'
    Landable::Local::ListType.lookup.seed      *%w[MENU BIOS PRODUCTS EVENTS]
    Landable::Local::PaymentMethod.lookup.seed *%w[AMERICANEXPRESS CASH CHECK DINERSCLUB DISCOVER FINANCING GOOGLECHECKOUT INVOICE MASTERCARD PAYPAL TRAVELERSCHECK VISA]

    execute <<-SQL
      -- Places for Business Help Center
      -- https://support.google.com/places/?hl=en#topic=4514728

      -- Create your bulk upload spreadsheet
      -- https://support.google.com/places/answer/1722104?hl=en

      CREATE TABLE #{local}.lists (
          list_id      SERIAL PRIMARY KEY
        , name         VARCHAR(32)
        , list_type_id SMALLINT
      );

      CREATE TABLE #{local}.locations (
          location_id           SERIAL       PRIMARY KEY

        , location_name         VARCHAR(60)  NOT NULL
        , location_code         VARCHAR(60)
        , location_type_id      SMALLINT              REFERENCES #{local}.location_types
        , containing_location   VARCHAR(255)

        , address1              VARCHAR(80)  NOT NULL
        , address2              VARCHAR(20)
        , city                  VARCHAR(80)  NOT NULL
        , neighborhood          VARCHAR(80)
        , state                 VARCHAR(80)  NOT NULL
        , zip                   VARCHAR(10)  NOT NULL
        , country               CHAR(2)      NOT NULL DEFAULT 'US'

        , phone                 VARCHAR(10)  NOT NULL
        , is_phone_tracked      BOOLEAN      NOT NULL DEFAULT FALSE

        , local_phone           VARCHAR(10)
        , alternate_phone       VARCHAR(10)
        , fax_phone             VARCHAR(10)
        , mobile_phone          VARCHAR(10)
        , toll_free_phone       VARCHAR(10)
        , tty_phone             VARCHAR(10)

        , suppress_address      BOOLEAN      NOT NULL DEFAULT FALSE

        -- PostgreSQL 9.4 might ship with 'ELEMENT REFERENCES table_name' to allow a FK here
        , category_ids          INTEGER[]

        , special_offer         VARCHAR(50)
        , special_offer_url     VARCHAR(255)

        , website_url           VARCHAR(255)
        , vanity_url            VARCHAR(255)
        , reservation_url       VARCHAR(255)

        , hours                 VARCHAR(255) -- Same format as Google Places upload, https://support.google.com/places/answers/1722104?topic=1656882&ctx=topic
        , additional_hours_text VARCHAR(255)

        , description           VARCHAR(2000)

        , closed_on             DATE
        , payment_method_ids    SMALLINT[]

        , logo_id               UUID             REFERENCES #{landable}.assets
        , photo_ids             UUID ARRAY[5]
        , video_ids             UUID ARRAY[5]

          -- no leading @
        , twitter_handle        VARCHAR(255)
        , facebook_page_url     VARCHAR(255)
        , pinterest_url         VARCHAR(255)
        , promotional_urls      VARCHAR(255) ARRAY[5]
        , year_established      CHAR(4)

        , display_lat           DOUBLE PRECISION
        , display_lng           DOUBLE PRECISION

        , routable_lat          DOUBLE PRECISION
        , routable_lng          DOUBLE PRECISION

        , display_point         GEOGRAPHY(POINT, 4326)
        , routable_point        GEOGRAPHY(POINT, 4326)

        , emails                VARCHAR(255) ARRAY[5]
        , specialties           VARCHAR(50)  ARRAY[10]
        , services              VARCHAR(50)  ARRAY[10]
        , brands                VARCHAR(50)  ARRAY[10]
        , languages             VARCHAR(50)  ARRAY[10]
        , keywords              VARCHAR(50)  ARRAY[10]

        , tagline               VARCHAR(150)

        , list_ids              INTEGER[]

        , folder_id             TEXT

        , google_ad_icon_url           VARCHAR(255)
        , google_ad_phone              VARCHAR(10)
        , google_ad_landing_page_url   VARCHAR(255)

        , custom_fields         HSTORE
      );

      CREATE INDEX ON #{local}.locations (location_code);

      ANALYZE #{local}.locations;
    SQL
  end
end

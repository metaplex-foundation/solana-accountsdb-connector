/**
 * This plugin implementation for PostgreSQL requires the following tables
 */

CREATE TYPE "SlotStatus" AS ENUM (
    'Rooted',
    'Confirmed',
    'Processed'
);

CREATE TABLE pubkey (
    pubkey_id BIGSERIAL PRIMARY KEY,
    pubkey VARCHAR(44) NOT NULL UNIQUE
);

-- Returns a pubkey_id for a pubkey, by getting it from the table or inserting it.
-- Getting this fully correct is complex, see:
-- https://stackoverflow.com/questions/15939902/is-select-or-insert-in-a-function-prone-to-race-conditions/15950324
-- and currently this function assumes there are no deletions in the pubkey table!
CREATE OR REPLACE FUNCTION map_pubkey(_pubkey varchar(44), OUT _pubkey_id bigint)
  LANGUAGE plpgsql AS
$func$
BEGIN
   LOOP
      SELECT pubkey_id
      FROM   pubkey
      WHERE  pubkey = _pubkey
      INTO   _pubkey_id;

      EXIT WHEN FOUND;

      INSERT INTO pubkey AS t
      (pubkey) VALUES (_pubkey)
      ON     CONFLICT (pubkey) DO NOTHING
      RETURNING t.pubkey_id
      INTO   _pubkey_id;

      EXIT WHEN FOUND;
   END LOOP;
END
$func$;

-- The table storing account writes, keeping only the newest write_version per slot
CREATE TABLE account_write (
    pubkey_id BIGINT NOT NULL REFERENCES pubkey,
    slot BIGINT NOT NULL,
    write_version BIGINT NOT NULL,
    owner_id BIGINT REFERENCES pubkey,
    lamports BIGINT NOT NULL,
    executable BOOL NOT NULL,
    rent_epoch BIGINT NOT NULL,
    data BYTEA,
    PRIMARY KEY (pubkey_id, slot, write_version)
);

-- The table storing slot information
CREATE TABLE slot (
    slot BIGINT PRIMARY KEY,
    parent BIGINT,
    status "SlotStatus" NOT NULL,
    uncle BOOL NOT NULL
);
CREATE INDEX ON slot (parent);
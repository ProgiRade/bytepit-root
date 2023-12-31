CREATE EXTENSION "uuid-ossp";

CREATE TYPE user_role AS ENUM ('admin', 'contestant', 'organiser');

CREATE TABLE users (
    id                  uuid            DEFAULT uuid_generate_v4() PRIMARY KEY,
    role                user_role       NOT NULL,
    username            VARCHAR(32)     NOT NULL CHECK (LENGTH(username) > 3) UNIQUE,
    image               BYTEA,
    password_hash       VARCHAR(255)    NOT NULL,
    email               VARCHAR(128)    NOT NULL CHECK (LENGTH(email) > 4) UNIQUE,
    name                VARCHAR(64)     NOT NULL,
    surname             VARCHAR(64)     NOT NULL,
    is_verified         BOOLEAN         NOT NULL,
    approved_by_admin   BOOLEAN         NOT NULL DEFAULT TRUE,
    created_on          TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX index_users_email ON users (email);

CREATE TABLE problems (
    id              uuid            DEFAULT uuid_generate_v4() PRIMARY KEY,
    name            TEXT            NOT NULL,
    example_input   TEXT            NOT NULL,
    example_output  TEXT            NOT NULL,
    is_hidden       BOOLEAN         NOT NULL,
    num_of_points   REAL            NOT NULL CHECK (num_of_points > 0),
    runtime_limit   REAL            NOT NULL,
    description     TEXT            NOT NULL,
    organiser_id    UUID            NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    is_private      BOOLEAN         NOT NULL,
    created_on      TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE TABLE competitions (
    id              uuid            DEFAULT uuid_generate_v4() PRIMARY KEY,
    name            TEXT            NOT NULL,
    description     TEXT            NOT NULL,
    start_time      TIMESTAMP       NOT NULL,
    end_time        TIMESTAMP       NOT NULL,
    parent_id       UUID            REFERENCES competitions(id) ON DELETE CASCADE,
    organiser_id    UUID            NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    problems        UUID[]
);

CREATE TABLE problem_results (
    id              uuid            DEFAULT uuid_generate_v4() PRIMARY KEY,
    problem_id      UUID            NOT NULL REFERENCES problems(id) ON DELETE CASCADE,
    competition_id  UUID            REFERENCES competitions(id) ON DELETE CASCADE,
    user_id         UUID            NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    average_runtime REAL            NOT NULL,
    is_correct      BOOLEAN         NOT NULL,
    num_of_points   REAL            NOT NULL,
    source_code     TEXT            NOT NULL,
    language        TEXT            NOT NULL
);

CREATE UNIQUE INDEX idx_unique_problem_user_when_competition_null
ON problem_results (problem_id, user_id) 
WHERE competition_id IS NULL;

CREATE UNIQUE INDEX idx_unique_problem_competition_user_when_competition_not_null
ON problem_results (problem_id, competition_id, user_id) 
WHERE competition_id IS NOT NULL;


CREATE TABLE trophies (
    id              uuid            DEFAULT uuid_generate_v4() PRIMARY KEY,
    competition_id  UUID            NOT NULL REFERENCES competitions(id) ON DELETE CASCADE,
    user_id         UUID            REFERENCES users(id) ON DELETE CASCADE,
    position        SMALLINT        NOT NULL CHECK (position > 0),
    icon            BYTEA           NOT NULL
);

CREATE TABLE verification_tokens (
    token          VARCHAR(255)    NOT NULL PRIMARY KEY UNIQUE,
    email          VARCHAR(128)    NOT NULL REFERENCES users(email) ON DELETE CASCADE,
    expiry_date    TIMESTAMP       NOT NULL DEFAULT NOW() + '2 day'::INTERVAL
);


CREATE OR REPLACE FUNCTION delete_confirmed_token() RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM verification_tokens WHERE email = OLD.email;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER delete_confirmed_token
AFTER UPDATE ON users 
FOR EACH ROW WHEN (OLD.is_verified = FALSE AND NEW.is_verified = TRUE)
EXECUTE FUNCTION delete_confirmed_token();

CREATE OR REPLACE FUNCTION delete_expired_tokens() RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM verification_tokens WHERE expiry_date < NOW();
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER delete_expired_tokens
AFTER INSERT ON verification_tokens
FOR EACH ROW
EXECUTE FUNCTION delete_expired_tokens();

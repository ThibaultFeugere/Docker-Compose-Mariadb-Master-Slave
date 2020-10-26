DROP DATABASE IF EXISTS teams;
CREATE DATABASE teams;
USE teams;
CREATE TABLE games
(
    id           VARCHAR(36) NOT NULL,
    match_date   DATETIME    NOT NULL,
    victory      BOOLEAN     NOT NULL,
    observations TEXT,
    PRIMARY KEY (id)
);
CREATE TABLE players
(
    id         VARCHAR(36)  NOT NULL,
    firstname  varchar(255) NOT NULL,
    lastname   varchar(255) NOT NULL,
    start_date DATE         NOT NULL,
    PRIMARY KEY (id)
);

INSERT INTO games VALUES (uuid(), '2020-12-02', 1, 'Exceptionnel');
INSERT INTO games VALUES (uuid(), '2022-12-02', 0, 'Decevant');
INSERT INTO games VALUES (uuid(), '2023-12-02', 1, 'Pas mal');

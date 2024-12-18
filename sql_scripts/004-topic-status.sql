CREATE TABLE topic_status (
    id INTEGER PRIMARY KEY NOT NULL,
    status_name TEXT NOT NULL UNIQUE
    );

INSERT INTO topic_status (status_name) VALUES
    ('STARTED'), ('DONE');

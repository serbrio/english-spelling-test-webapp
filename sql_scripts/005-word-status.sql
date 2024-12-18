CREATE TABLE word_status (
    id INTEGER PRIMARY KEY NOT NULL,
    status_name TEXT NOT NULL UNIQUE
    );

INSERT INTO word_status (status_name) VALUES
    ('N/A'), ('OK'), ('FAILED');
    
CREATE TABLE topics (
    id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
    topicname TEXT NOT NULL,
    block_id INTEGER NOT NULL,
    max_points INTEGER NOT NULL DEFAULT 0,
    words_count INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY(block_id) REFERENCES blocks(id)
    );

CREATE UNIQUE INDEX topicname_block_id ON topics (topicname, block_id);


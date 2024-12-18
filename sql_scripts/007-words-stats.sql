CREATE TABLE words_stats (
    word_id INTEGER NOT NULL,
    status_id INTEGER NOT NULL DEFAULT 1,
    cur_points INTEGER NOT NULL DEFAULT 0,
    user_id INTEGER NOT NULL,
    topic_id INTEGER NOT NULL,
    FOREIGN KEY(word_id) REFERENCES words(id),
    FOREIGN KEY(status_id) REFERENCES word_status(id),
    FOREIGN KEY(user_id) REFERENCES users(id),
    FOREIGN KEY(topic_id) REFERENCES topics(id)
    );

CREATE UNIQUE INDEX word_user ON words_stats (word_id, topic_id, user_id);

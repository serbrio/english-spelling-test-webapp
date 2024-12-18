CREATE TABLE topics_stats (
    topic_id INTEGER NOT NULL,
    status_id INTEGER NOT NULL DEFAULT 1,
    best_points INTEGER NOT NULL DEFAULT 0,
    cur_points INTEGER NOT NULL DEFAULT 0,
    user_id INTEGER NOT NULL,
    FOREIGN KEY(topic_id) REFERENCES topics(id),
    FOREIGN KEY(status_id) REFERENCES topic_status(id),
    FOREIGN KEY(user_id) REFERENCES users(id)
    );

CREATE UNIQUE INDEX topic_user ON topics_stats (topic_id, user_id);


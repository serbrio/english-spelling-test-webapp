CREATE TABLE topics_words (
    word_id INTEGER NOT NULL,
    topic_id INTEGER NOT NULL,
    FOREIGN KEY(word_id) REFERENCES words(id),
    FOREIGN KEY(topic_id) REFERENCES topics(id)
    );

CREATE UNIQUE INDEX topics_lists ON topics_words (word_id, topic_id);


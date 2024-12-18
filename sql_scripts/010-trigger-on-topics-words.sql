CREATE TRIGGER update_topics_and_wordsstats_after_word_insert AFTER INSERT ON topics_words
    BEGIN
        UPDATE topics
        SET words_count = words_count + 1,
            max_points = (max_points + (SELECT LENGTH(word) from words WHERE id = NEW.word_id))
        WHERE id = NEW.topic_id;

        /* When appears a new pair of topic and word in topics_words, UPDATE words_stats: */
        /* INSERT (word_id, topic_id, user_id) for those users, which already have this topic in words_stats.*/
        INSERT INTO words_stats (word_id, topic_id, user_id)
            SELECT DISTINCT NEW.word_id, NEW.topic_id, user_id FROM words_stats
                WHERE topic_id = NEW.topic_id;
    END;

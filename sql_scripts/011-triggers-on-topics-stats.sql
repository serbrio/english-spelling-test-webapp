CREATE TRIGGER update_words_status_after_topics_stats_insert AFTER INSERT ON topics_stats
    BEGIN
        INSERT INTO words_stats (word_id, topic_id, user_id)
            SELECT word_id, NEW.topic_id, NEW.user_id FROM topics_words
                WHERE topic_id = NEW.topic_id;
    END;

CREATE TRIGGER update_words_status_NA_topics_curpts_0_after_topic_status_STARTED AFTER UPDATE OF status_id ON topics_stats
    WHEN NEW.status_id = 1
    BEGIN
        UPDATE topics_stats
        SET cur_points = 0
        WHERE topic_id = NEW.topic_id
            AND user_id = NEW.user_id;

        UPDATE words_stats
        SET status_id = 1, cur_points = 0
        WHERE topic_id = NEW.topic_id
            AND user_id = NEW.user_id;
    END;

CREATE TRIGGER update_best_points_after_status_DONE AFTER UPDATE OF status_id ON topics_stats
    WHEN NEW.status_id = 2
        AND OLD.cur_points > OLD.best_points
    BEGIN
        UPDATE topics_stats
        SET best_points = OLD.cur_points
        WHERE topic_id = OLD.topic_id
            AND user_id = OLD.user_id;
    END;

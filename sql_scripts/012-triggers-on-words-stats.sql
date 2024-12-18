CREATE TRIGGER update_topics_status_to_DONE_after_words_status_update AFTER UPDATE OF status_id ON words_stats
    WHEN NEW.status_id != 1
        AND
            (SELECT words_count FROM topics
                WHERE id = NEW.topic_id
            )
            =
            (SELECT COUNT() FROM words_stats
                WHERE topic_id = NEW.topic_id
                    AND user_id = NEW.user_id
                    AND status_id != 1
            )
    BEGIN
        UPDATE topics_stats
        SET status_id = 2
        WHERE topic_id = NEW.topic_id
            AND user_id = NEW.user_id;
    END;

/* Order of triggers matters: if next trigger goes first, cases with status_id=2 will not be processed somehow */
/* TODO: pack it all in one TRIGGER, see: https://sqlfiddle.com/sqlite/online-compiler?sqlFiddleLegacyID=5-78288-1 */

CREATE TRIGGER update_topic_cur_points_after_word_status_OK AFTER UPDATE OF status_id ON words_stats
    WHEN NEW.status_id = 2
        AND NEW.cur_points > 0
    BEGIN
        UPDATE topics_stats
        SET cur_points = cur_points + NEW.cur_points
        WHERE topic_id = OLD.topic_id
            AND user_id = OLD.user_id;
    END;

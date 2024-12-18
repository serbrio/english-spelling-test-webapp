#
# Populate DB according to dirs and files structrure:
# dir name =>  blockname,
# file name => topicname,
# words in file => words.
#

import os
import sys
import fileinput
import argparse
from pathlib import Path

from helpers import execute_sql
from get_links import GetLinks


# TODO: ?add success report for all operations?


def process_blocks(blocks_dir, db):
    for block_name in os.listdir(blocks_dir):
        if os.path.isdir(os.path.join(blocks_dir, block_name)):
            _, block_id = execute_sql(
                db,
                "INSERT INTO blocks (blockname) VALUES(?)",
                block_name
                )
            if not block_id:
                print(f"| i| Failed to insert BLOCK: '{block_name}'. Going on with it's topics...")
                # Get block_id from DB
                rows, _ = execute_sql(
                    db,
                    "SELECT id FROM blocks WHERE blockname=?",
                    block_name
                    )
                block_id = rows[0]["id"]
            else:
                print(f"|OK| Inserted BLOCK: {block_name}")
            process_topics(block_name, blocks_dir, block_id, db)


def process_topics(block_name, blocks_dir, block_id, db):
    block_path = os.path.join(blocks_dir, block_name)
    topics = {}

    for topic in os.listdir(block_path):
        topic_path = os.path.join(block_path, topic)
        if os.path.isfile(topic_path):
            topic_name = Path(topic).stem
            _, topic_id = execute_sql(
                db,
                "INSERT INTO topics (topicname, block_id) VALUES (?, ?)",
                topic_name, block_id
                )
            if not topic_id:
                print(f"| i| Failed to insert TOPIC: '{topic_name}'. Going on with its WORDS...")
                rows, _ = execute_sql(
                    db,
                    "SELECT id FROM topics WHERE topicname=? and block_id=?",
                    topic_name, block_id
                    )
                topic_id = rows[0]["id"]
            else:
                print(f"|OK| Inserted TOPIC: {topic_name} (BLOCK: {block_name})")
            # Topic processed further in order to check words in it and not to skip new ones
            topics[topic_path] = {"topic_name": topic_name, "topic_id": topic_id, "words": []}
    process_words(topics, db)


def process_words(topics, db):
    topic_paths = topics.keys()
    words = set() # set of all words, which will be used in GetLinks
    with fileinput.input(files=topic_paths, encoding="utf-8") as f:
        for line in f:
            word = line.strip()
            if not word:
                continue
            # Add word to set "words" (unique words)
            words.add(word)
            # Add word to dictionary "topics" into appropriate topic's list
            topics[f.filename()]["words"].append(word)
    # TODO: think about skipping words, which already have links,
    # TODO: but mind the case when a word-1 exist in a topic-1 and added to the topic-2.
    # list(set(x)-set(y))
    # set(from DB table 'words') - set(words found in txt-files)

    # Get a dictionary of words with existing links
    words_links, _ = GetLinks.get_links(words)

    # TODO: think about using execute_many_sqls?

    for topic in topics.values():
        for word in topic["words"]:
            if word in words_links: # if link for word found
                _, word_id = execute_sql(
                    db,
                    "INSERT INTO words (word, link) VALUES (?, ?)",
                    word, words_links[word]
                )
                if not word_id:
                    # If "INSERT INTO words" failed,
                    # get word_id from DB
                    rows, _ = execute_sql(
                        db,
                        "SELECT id FROM words WHERE word=?",
                        word
                    )
                    word_id = rows[0]["id"]
                else:
                    print(f'|OK| Inserted WORD: {word} (TOPIC: {topic["topic_name"]})')
                # And try to update topics_words;
                # will be added, if word is new for this topic;
                # will not be added, if word existed in this topic.
                execute_sql(
                    db,
                    "INSERT INTO topics_words (word_id, topic_id) VALUES (?, ?)",
                    word_id, topic["topic_id"]
                )
            else:
                print(f"| !| LINK NOT FOUND for: {word}")


def main():
    parser = argparse.ArgumentParser(description="Populating DB")
    parser.add_argument("-d", "--blocksdir", default="./src/words",
                        help="path to the directory with blocks (default: './src/words')")
    parser.add_argument("-db", "--database",
                        help="path to the DB to be populated")

    args = parser.parse_args()
    blocks_dir = args.blocksdir
    db = args.database

    if not db:
        print("Compulsory argument is missing: DATABASE")
        parser.print_usage()
        sys.exit(1)

    process_blocks(blocks_dir, db)


if __name__ == "__main__":
    main()

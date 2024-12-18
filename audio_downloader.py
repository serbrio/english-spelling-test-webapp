import requests
import os
import argparse
#import urllib.request
import sys

from time import sleep
from helpers import execute_sql


def get_words(db):
    words, _ = execute_sql(
        db,
        "SELECT * FROM words"
    )
    return words


def download_audio(word: dict, headers, filepath):
    try:
        # _, _ = urllib.request.urlretrieve(word["link"], filepath)
        r = requests.get(word["link"], headers=headers, allow_redirects=True, stream=True)
    except requests.exceptions.RequestException as e:
        print(f"FAILED: {word['link']}")
        print(f"{e}\n")
        return 1
    with open(filepath, 'wb') as f:
        for chunk in r.iter_content(chunk_size=1024):
            if chunk:
                f.write(chunk)
    r.close()
    print(f"HTTP: {r.status_code} || '{word["word"]}' saved to: {filepath}")
    return 0


def process_downloading(words, audio_dir):
    fails = 0
    headers = {"User-Agent": "EnglishSpellingTest/0.2 (Educational project) audio_downloader/0.1"}

    if not os.path.isdir(audio_dir):
        os.mkdir(audio_dir)

    for word in words:
        filepath = os.path.join(audio_dir, str(word["id"]))
        if os.path.isfile(filepath):
            print(f"Exists: {word["word"]} ({filepath})")
        else:
            fails += download_audio(word, headers, filepath)
            sleep(0.1) # to not overload wikimedia :)
    print("=" * 30)
    print(f"TOTAL: {len(words) - fails} of {len(words)} OK.")
    print(f"FAILED: {fails}")


def main():
    parser = argparse.ArgumentParser(description="Download audio")
    parser.add_argument("-d", "--audiodir", default="./src/audio",
                        help="path to the directory with audio (default: './src/audio')")
    parser.add_argument("-db", "--database",
                        help="path to the DB")
    args = parser.parse_args()
    audio_dir = args.audiodir
    db = args.database

    if not db:
        print("Compulsory argument is missing: DATABASE")
        parser.print_usage()
        sys.exit(1)

    words = get_words(db)
    process_downloading(words, audio_dir)


if __name__ == "__main__":
    main()

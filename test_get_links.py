import re
import pytest

from get_links import GetLinks


def test_GetLinks_get_link_correct():
	correct_word = "purple"
	link = GetLinks.get_link(correct_word)
	assert correct_word in link
	match = re.search(r"^https+://.*$", link)
	assert match != None


def test_GetLinks_get_link_not_exist():
	not_exist = "riumambaharamamburu"
	with pytest.raises(FileNotFoundError):
		link = GetLinks.get_link(not_exist)


def test_GetLinks_get_links_all_correct():
	words = ["yellow", "red", "green"]
	words_links, notfound_words = GetLinks.get_links(words)
	assert isinstance(words_links, dict) == True
	assert isinstance(notfound_words, list) == True
	# Check, if every existent english word in words got a link,
	# assume internet and wiktionary.org resources are available.
	assert set(words).intersection(words_links.keys()) == set(words)
	# Check, if links contains appropriate words
	# (word-link pairs are not jumbled).
	for word, link in words_links.items():
		assert word in link
	# Check, if not a word is lost: sum of found and notfound contains
	# the same words as words list.
	assert len(words_links) + len(notfound_words) == len(words)
	assert set(words).intersection(list(words_links.keys()) + notfound_words) == set(words)


def test_GetLinks_get_links_correct_and_incorrect():
    correct_words = ["dog", "cat"]
    incorrect_words = ["thatisnotaword"]
    words = correct_words + incorrect_words
    words_links, notfound_words = GetLinks.get_links(words)
    assert isinstance(words_links, dict) == True
    assert isinstance(notfound_words, list) == True
    # Check, if every existent english word in words got a link,
    # and nonexistent word does not,
    # assume internet and wiktionary.org resources are available.
    assert set(words).intersection(words_links.keys()) != set(words)
    assert set(incorrect_words).intersection(notfound_words) == set(incorrect_words)
    assert set(correct_words).intersection(words_links.keys()) == set(correct_words)
    # Check, if links contains appropriate words
    # (word-link pairs are not jumbled).
    for word, link in words_links.items():
        assert word in link
    # Check, if not a word is lost: 
    # sum of found and notfound contains the same words.
    assert len(words_links) + len(notfound_words) == len(words)
    assert set(words).intersection(list(words_links.keys()) + notfound_words) == set(words)


def test_GetLinks_get_links_all_incorrect():
    words = ["ramambahararamburushka", "qqqqfffaaa"]
    words_links, notfound_words = GetLinks.get_links(words)
    assert isinstance(words_links, dict) == True
    assert isinstance(notfound_words, list) == True
    # Check, that all nonexistent words do not get a link,
    # assume internet and wiktionary.org resources are available.
    assert set(words).intersection(words_links.keys()) != set(words)
    assert set(words).intersection(notfound_words) == set(words)
    assert len(words_links) == 0
    # Check, if not a word is lost: sum of found and notfound contains
    # the same words as words list.
    assert len(words_links) + len(notfound_words) == len(words)
    assert set(words).intersection(list(words_links.keys()) + notfound_words) == set(words)


import concurrent.futures
import threading
import requests

from urllib.parse import urlparse

import time


class GetLinks:
	"""
	A class to scrape wiktionary.org in parallel threads
	in order to get links to audio files with pronunciation
	of the given English words.

	Attributes
	----------
	thread_local : instance of class threading.local
		manages thread-local data of the executed threads
	"""

	thread_local = threading.local()


	@classmethod
	def get_link(cls, word):
		"""
		Scrapes wiktionary.org to get a link to audio file
		with pronunciation of an English "word".
    	If link not found, a FileNotFoundError is raised.
		"""
		
		wiktionary_url = 'https://en.wiktionary.org/w/rest.php/v1/page/' + word + '/links/media'
		headers = {'User-Agent': 'EnglishSpelling/0.0 (https://github.com/serbrio/english-spelling-test-webapp)'}
		session = cls.thread_local.session = requests.Session()
		response = session.get(url=wiktionary_url, headers=headers)

		# raise FileNotFoundError, if status not OK
		if response.status_code != 200:
			raise FileNotFoundError
		
		res_json = response.json()

		# TODO: get image link

		for media in res_json['files']:
			if media['original']['mediatype'] == 'AUDIO':
				media_url = media['original']['url']
				# parse url, get rid of 'http' or '//' prefix
				media_url_parsed = urlparse(media_url)
				result_link = media_url_parsed.netloc + media_url_parsed.path
				return result_link
		# if 'pronunciation' is empty [] or does not contain
		# corresponding values, raise FileNotFoundError
		raise FileNotFoundError


	@classmethod
	def get_links(cls, words):
		"""
		In parallel executes method GetLinks.get_link() for every word in a set of "words".
		Returns a tuple of:
		a dictionary with words as keys and found links as values,
		a list of words, for which links were not found.
		"""
		words = set(words)
		words_links = {}
		notfound_words = []
		# TODO: get image links
		with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
			future_to_url = {executor.submit(cls.get_link, word): word for word in words}
		for future in concurrent.futures.as_completed(future_to_url):
			wrd = future_to_url[future]
			try:
				words_links[wrd] = future.result()
			except FileNotFoundError:
				notfound_words.append(wrd)
		return words_links, notfound_words


def main():
	"""
	Demonstrate how the GetLinks.get_links(words) works for a given list of words:
	print the duration of the execution,
	print the words with the found links (enumerated),
	print the not found words in a separate list.
	"""
	words = ["cat", "dog", "pig", "ant",
			"bumblebee", "horse", "owl",
			"cow", "lion", "monkey",
			"bee", "frog", "spider",
			"notevenaword", "chupakabra", 'biber']

	start_time = time.time()
	words_links, notfound_words = GetLinks.get_links(words)
	duration = time.time() - start_time
	print(f"Duration: {duration}")

	for i, key in enumerate(words_links, start=1):
		print(f"{i}. {key}: {words_links[key]}")

	print(f"Not found {len(notfound_words)} words:", notfound_words)


if __name__ == "__main__":
	main()

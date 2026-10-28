import 'package:flutter_test/flutter_test.dart';
import 'package:sonde/features/podcast/data/utils/podcast_url_utils.dart';

void main() {
  group('PodcastUrlUtils', () {
    group('normalizeFeedUrl', () {
      test('should remove trailing slash', () {
        expect(
          PodcastUrlUtils.normalizeFeedUrl('https://example.com/feed/'),
          'https://example.com/feed',
        );
      });

      test('should convert http to https', () {
        expect(
          PodcastUrlUtils.normalizeFeedUrl('http://example.com/feed.xml'),
          'https://example.com/feed.xml',
        );
      });

      test('should convert to lowercase', () {
        expect(
          PodcastUrlUtils.normalizeFeedUrl('https://EXAMPLE.COM/Feed.XML'),
          'https://example.com/feed.xml',
        );
      });

      test('should handle combined transformations', () {
        expect(
          PodcastUrlUtils.normalizeFeedUrl('http://EXAMPLE.COM/Feed/'),
          'https://example.com/feed',
        );
      });

      test('should trim whitespace', () {
        expect(
          PodcastUrlUtils.normalizeFeedUrl('  https://example.com/feed  '),
          'https://example.com/feed',
        );
      });
    });

    group('feedUrlMatches', () {
      test('should return true for identical URLs', () {
        expect(
          PodcastUrlUtils.feedUrlMatches(
            'https://example.com/feed.xml',
            'https://example.com/feed.xml',
          ),
          true,
        );
      });

      test('should return true for http vs https', () {
        expect(
          PodcastUrlUtils.feedUrlMatches(
            'https://example.com/feed.xml',
            'http://example.com/feed.xml',
          ),
          true,
        );
      });

      test('should return true for trailing slash difference', () {
        expect(
          PodcastUrlUtils.feedUrlMatches(
            'https://example.com/feed.xml',
            'https://example.com/feed.xml/',
          ),
          true,
        );
      });

      test('should return true for case difference', () {
        expect(
          PodcastUrlUtils.feedUrlMatches(
            'https://example.com/feed.xml',
            'https://EXAMPLE.COM/Feed.XML',
          ),
          true,
        );
      });

      test('should return true for combined differences', () {
        expect(
          PodcastUrlUtils.feedUrlMatches(
            'https://example.com/feed.xml',
            'http://EXAMPLE.COM/Feed.XML/',
          ),
          true,
        );
      });

      test('should return false for different URLs', () {
        expect(
          PodcastUrlUtils.feedUrlMatches(
            'https://example.com/feed1.xml',
            'https://example.com/feed2.xml',
          ),
          false,
        );
      });

      test('should return false when either URL is null', () {
        expect(
          PodcastUrlUtils.feedUrlMatches(null, 'https://example.com/feed.xml'),
          false,
        );
        expect(
          PodcastUrlUtils.feedUrlMatches('https://example.com/feed.xml', null),
          false,
        );
        expect(
          PodcastUrlUtils.feedUrlMatches(null, null),
          false,
        );
      });
    });

    group('isValidFeedUrl', () {
      test('should return true for valid https URL', () {
        expect(
          PodcastUrlUtils.isValidFeedUrl('https://example.com/feed.xml'),
          true,
        );
      });

      test('should return true for valid http URL', () {
        expect(
          PodcastUrlUtils.isValidFeedUrl('http://example.com/feed.xml'),
          true,
        );
      });

      test('should return false for null', () {
        expect(PodcastUrlUtils.isValidFeedUrl(null), false);
      });

      test('should return false for empty string', () {
        expect(PodcastUrlUtils.isValidFeedUrl(''), false);
        expect(PodcastUrlUtils.isValidFeedUrl('   '), false);
      });

      test('should return false for ftp URL', () {
        expect(
          PodcastUrlUtils.isValidFeedUrl('ftp://example.com/feed.xml'),
          false,
        );
      });

      test('should return false for URL without scheme', () {
        expect(
          PodcastUrlUtils.isValidFeedUrl('example.com/feed.xml'),
          false,
        );
      });

      test('should return false for URL without host', () {
        expect(PodcastUrlUtils.isValidFeedUrl('https://'), false);
        expect(PodcastUrlUtils.isValidFeedUrl('http:///feed.xml'), false);
      });

      test('should return false for malformed URL', () {
        expect(PodcastUrlUtils.isValidFeedUrl('not a url'), false);
        expect(PodcastUrlUtils.isValidFeedUrl('https://'), false);
      });
    });

    group('findMatchingFeedUrl', () {
      test('should return first matching URL', () {
        const candidates = [
          'https://example.com/feed1.xml',
          'http://example.com/feed2.xml/',
          'https://example.com/feed3.xml',
        ];

        expect(
          PodcastUrlUtils.findMatchingFeedUrl(
            'https://example.com/feed2.xml',
            candidates,
          ),
          'http://example.com/feed2.xml/',
        );
      });

      test('should return null when no match found', () {
        const candidates = [
          'https://example.com/feed1.xml',
          'https://example.com/feed2.xml',
        ];

        expect(
          PodcastUrlUtils.findMatchingFeedUrl(
            'https://other.com/feed.xml',
            candidates,
          ),
          null,
        );
      });

      test('should return null for null targetUrl', () {
        expect(
          PodcastUrlUtils.findMatchingFeedUrl(null, ['https://example.com/feed.xml']),
          null,
        );
      });

      test('should return null for empty candidates', () {
        expect(
          PodcastUrlUtils.findMatchingFeedUrl('https://example.com/feed.xml', []),
          null,
        );
      });
    });

    group('extractFeedId', () {
      test('should return normalized URL as ID', () {
        expect(
          PodcastUrlUtils.extractFeedId('http://EXAMPLE.COM/Feed/'),
          'https://example.com/feed',
        );
      });

      test('should be consistent for equivalent URLs', () {
        const url1 = 'https://example.com/feed.xml';
        const url2 = 'http://EXAMPLE.COM/Feed.XML/';

        expect(
          PodcastUrlUtils.extractFeedId(url1),
          PodcastUrlUtils.extractFeedId(url2),
        );
      });
    });
  });
}

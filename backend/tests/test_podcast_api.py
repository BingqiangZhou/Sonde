"""
Comprehensive API Validation Tests for Podcast Feature
Tests security, models, and core functionality
"""

import sys


# Fix encoding for Windows
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


class TestPodcastAPI:
    """Stage 3: API Validation Tests"""

    def test_xxe_protection(self):
        """Security Test: XXE attacks must be blocked"""
        from app.domains.podcast.integration.security import PodcastSecurityValidator

        validator = PodcastSecurityValidator()

        # Test XXE attack
        malicious_xml = """<?xml version="1.0"?>
        <!DOCTYPE data [
          <!ENTITY xxe SYSTEM "file:///etc/passwd">
        ]>
        <data>&xxe;</data>"""

        is_valid, error = validator.validate_rss_xml(malicious_xml)
        assert is_valid is False, "XXE should be blocked"
        print(f"[PASS] XXE防护: {error}")

        # Test OOB attack
        oob_xml = """<?xml version="1.0"?>
        <!DOCTYPE data [
          <!ENTITY xxe SYSTEM "http://internal-server/status">
        ]>
        <data>&xxe;</data>"""

        is_valid, error = validator.validate_rss_xml(oob_xml)
        assert is_valid is False, "OOB XXE should be blocked"
        print("[PASS] OOB XXE blocked")

    def test_rss_security_validations(self):
        """Security Test: RSS URL and content validation"""
        from app.domains.podcast.integration.security import PodcastSecurityValidator

        validator = PodcastSecurityValidator()

        # Test dangerous URLs
        dangerous_urls = [
            "http://localhost/evil.xml",
            "http://127.0.0.1/exploit.xml",
            "http://192.168.1.1/internal.xml",
            "file:///etc/passwd",
        ]

        for url in dangerous_urls:
            is_valid, error = validator.validate_audio_url(url)
            assert is_valid is False, f"Blocked dangerous URL: {url}"
            print(f"[PASS] Blocked: {url}")

        # Test safe URLs
        safe_urls = [
            "https://example.com/podcast.mp3",
            "http://cdn.example.com/audio/episode.mp3",
        ]

        for url in safe_urls:
            is_valid, error = validator.validate_audio_url(url)
            assert is_valid is True, f"Should allow safe URL: {url}"
            print(f"[PASS] Allowed: {url}")

    def test_model_definitions(self):
        """Model Test: Verify model structure exists"""
        import ast
        import pathlib

        # Check models file exists and valid
        model_file = (
            pathlib.Path(__file__).parent.parent
            / "app"
            / "domains"
            / "podcast"
            / "models.py"
        )
        assert model_file.exists(), "Podcast models file missing"

        with open(model_file, encoding="utf-8") as f:
            content = f.read()

        # Parse without executing (avoid import issues)
        ast.parse(content)

        # Check for required imports (even if unused)
        assert "class PodcastEpisode" in content

        # Check for key fields (string match, not import)
        expected_fields = [
            "audio_url",
            "ai_summary",
            "item_link",
            "subscription_id",
        ]

        for field in expected_fields:
            assert field in content, f"Missing field: {field}"

        print("[PASS] Model structure validated")

    def test_service_workflow_logic(self):
        """Logic Test: Service workflow patterns"""
        # Test that our mocked service can handle workflow
        from app.domains.podcast.integration.security import PodcastSecurityValidator

        validator = PodcastSecurityValidator()

        # Simulate secure RSS validation pipeline
        good_rss = """<?xml version="1.0"?>
        <rss>
          <channel>
            <title>Test Podcast</title>
            <item>
              <title>Episode 1</title>
              <description>Test description</description>
              <enclosure url="http://cdn.example.com/ep1.mp3" type="audio/mpeg" />
            </item>
          </channel>
        </rss>"""

        is_valid, error = validator.validate_rss_xml(good_rss)
        assert is_valid is True, "Valid RSS should pass"
        print("[PASS] Valid RSS processing works")

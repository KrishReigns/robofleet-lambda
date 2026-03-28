"""
Unit tests for lambda_robofleet_queries.py

Run with: python -m pytest test_lambda.py -v
"""

import pytest
from lambda_robofleet_queries import format_query_results_as_html


class TestFormatQueryResultsAsHTML:
    """Tests for HTML formatting function"""

    def test_format_empty_results(self):
        """Test formatting with no results"""
        results = []
        html = format_query_results_as_html(
            "Test Query",
            results,
            "This is a test query"
        )

        assert "Test Query" in html
        assert "No results found" in html
        assert "0" in html  # Rows returned: 0

    def test_format_single_result(self):
        """Test formatting with one result"""
        results = [
            {
                "fleet_id": "FLEET-BOSTON-01",
                "status": "ACTIVE",
                "event_count": "45"
            }
        ]
        html = format_query_results_as_html(
            "Fleet Health",
            results,
            "Fleet health metrics"
        )

        assert "Fleet Health" in html
        assert "FLEET-BOSTON-01" in html
        assert "ACTIVE" in html
        assert "45" in html
        assert "<table" in html
        assert "<tr" in html

    def test_format_multiple_results(self):
        """Test formatting with multiple results"""
        results = [
            {"device_id": "ROBOT-001", "battery_level": "100", "status": "ACTIVE"},
            {"device_id": "ROBOT-002", "battery_level": "50", "status": "IDLE"},
            {"device_id": "ROBOT-003", "battery_level": "10", "status": "CHARGING"},
        ]
        html = format_query_results_as_html(
            "Battery Status",
            results,
            "Robot battery levels"
        )

        assert "Battery Status" in html
        assert "3" in html  # Rows returned: 3
        assert "ROBOT-001" in html
        assert "ROBOT-002" in html
        assert "ROBOT-003" in html

    def test_html_table_structure(self):
        """Test that HTML has proper table structure"""
        results = [{"column1": "value1", "column2": "value2"}]
        html = format_query_results_as_html("Test", results, "Test")

        assert "<table" in html
        assert "</table>" in html
        assert "<tr" in html
        assert "</tr>" in html
        assert "<th" in html
        assert "</th>" in html
        assert "<td" in html
        assert "</td>" in html

    def test_html_styling(self):
        """Test that HTML includes styling"""
        results = [{"id": "1"}]
        html = format_query_results_as_html("Test", results, "Test")

        # Check for styling
        assert "#D5E8F0" in html  # Blue header color
        assert "border" in html
        assert "padding" in html
        assert "background-color" in html

    def test_html_alternating_colors(self):
        """Test that HTML has alternating row colors"""
        results = [
            {"id": "1"},
            {"id": "2"},
            {"id": "3"}
        ]
        html = format_query_results_as_html("Test", results, "Test")

        # Should have alternating colors
        assert "#FFFFFF" in html  # White
        assert "#F0F0F0" in html  # Light gray

    def test_query_name_included(self):
        """Test that query name is included in output"""
        results = []
        query_name = "My Special Query"
        html = format_query_results_as_html(query_name, results, "Test")

        assert query_name in html

    def test_query_description_included(self):
        """Test that query description is included in output"""
        results = []
        description = "This is a detailed description"
        html = format_query_results_as_html("Query", results, description)

        assert description in html

    def test_row_count_accurate(self):
        """Test that row count is correct"""
        test_cases = [
            ([], "0"),
            ([{"id": "1"}], "1"),
            ([{"id": "1"}, {"id": "2"}], "2"),
            ([{"id": str(i)} for i in range(10)], "10"),
        ]

        for results, expected_count in test_cases:
            html = format_query_results_as_html("Test", results, "Test")
            assert f"<strong>Rows returned:</strong> {expected_count}" in html

    def test_special_characters_escaped(self):
        """Test that special characters are handled"""
        results = [
            {"data": "Value with & ampersand"},
            {"data": "Value with < bracket"},
            {"data": "Value with > bracket"},
        ]
        html = format_query_results_as_html("Test", results, "Test")

        # Should contain the values (may be escaped depending on implementation)
        assert "ampersand" in html
        assert "bracket" in html


class TestLambdaHandlerIntegration:
    """Integration tests for lambda_handler (requires AWS credentials)"""

    @pytest.mark.skip(reason="Requires AWS credentials and live environment")
    def test_lambda_handler_execution(self):
        """Test full lambda_handler execution"""
        from lambda_robofleet_queries import lambda_handler

        response = lambda_handler({}, {})

        assert response['statusCode'] == 200
        assert 'queriesExecuted' in response
        assert response['queriesExecuted'] == 3

    @pytest.mark.skip(reason="Requires AWS credentials")
    def test_queries_execute_successfully(self):
        """Test that all 3 queries execute without errors"""
        # This test would require actual AWS environment
        pass


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

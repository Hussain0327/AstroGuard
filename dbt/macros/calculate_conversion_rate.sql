{% macro calculate_conversion_rate(numerator, denominator, decimal_places=2) %}
    round(
        {{ numerator }}::decimal / nullif({{ denominator }}, 0) * 100,
        {{ decimal_places }}
    )
{% endmacro %}

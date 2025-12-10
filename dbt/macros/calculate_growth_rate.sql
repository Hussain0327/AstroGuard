{% macro calculate_growth_rate(current_value, previous_value, decimal_places=2) %}
    case
        when {{ previous_value }} is null or {{ previous_value }} = 0 then null
        else round(
            ({{ current_value }} - {{ previous_value }})::decimal
            / {{ previous_value }} * 100,
            {{ decimal_places }}
        )
    end
{% endmacro %}

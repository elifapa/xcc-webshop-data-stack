{#
    This macro will create custom names for tables/views created by dbt.
    For dev: it will create names as schema_name__table_name.
        e.g. staging__customers
    For prod:

#}
{% macro generate_alias_name(custom_alias_name=none, node=none) -%}
    {# Checks custom_alias_Name #}
    {%- if custom_alias_name is none -%} {%- set table_name = node.name -%}
    {%- else -%} {%- set table_name = custom_alias_name ~ "_" ~ node.name | trim -%}
    {%- endif -%}

    {%- if target.name == "dev" or target.name == "test" -%}
        {#- Get the custom schema name -#}
        {%- set schema_prefix = node.unrendered_config.schema | trim %}

        {#- Highlight if schema hasnt been assigned right -#}
        {%- if not schema_prefix -%}
            {%- set schema_prefix = "NO_ASSIGNED_SCHEMA" %}
        {%- endif -%}

        {{ schema_prefix ~ "__" ~ table_name }}

    {%- else -%} {{ table_name }}

    {%- endif -%}

{%- endmacro %}

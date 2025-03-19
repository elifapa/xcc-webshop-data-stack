{#
    If running in sample-dev environment, samples the data by indexed id,
    and returns sample_size number of rows.
    Saves the result into target.schema in sample-dev.
    In any other target environment, exits the execution.
#}
{% macro sample_by_id_fixed_rows(indexed_column) -%}
    {% set foreign_table_schema = "raw_prod" %}
    {% set sample_target_output = "sample-dev" %}

    {% if target.name != sample_target_output %}
        {{
            log(
                "Skipping sample table creation because target is not "
                ~ sample_target_output,
                info=True,
            )
        }}
        {% do return(None) %}
    {% endif %}

    {% set sources = [] %}

    {% do log("Scanning all the sources in dbt project", info=True) %}

    {% for node in graph.sources.values() %}
        {% do sources.append(node.name) %}
        {% do log("Source: " ~ node.unique_id, info=True) %}
    {% endfor %}

    {%- for source in sources -%}
        {% do log("Creating sampled table " ~ source ~ "...", info=True) %}

        {% set drop_sql %}
            CREATE SCHEMA IF NOT EXISTS {{target.schema}};
            drop table if exists {{target.schema}}.{{ source }};
        {% endset %}

        {% do run_query(drop_sql) %}

        {% set create_sql %}
            CREATE TABLE {{target.schema}}.{{ source }}  AS
            WITH RANDOMISED AS (
                SELECT {{indexed_column}}, RANDOM() AS rand_rn
                FROM {{foreign_table_schema}}.{{ source }}
            )
            SELECT *
            FROM {{foreign_table_schema}}.{{ source }}
            WHERE {{indexed_column}} IN (
                SELECT {{indexed_column}}
                FROM RANDOMISED
                ORDER BY rand_rn
                LIMIT {{ var('sample_size') }}
                )

        {% endset %}

        {% do run_query(create_sql) %}

        {% do log(
            "Sampled table "
            ~ target.schema
            ~ "."
            ~ source
            ~ " is created! Rejoice!",
            info=True,
        ) %}

    {%- endfor -%}

{%- endmacro %}


{#
    If running in sample-dev environment, samples the data by indexed id,
    and returns subset of rows which is sample_size_ratio percent of total rows.
    Saves the result into target.schema in sample-dev.
    In any other target environment, exits the execution.
#}
{% macro sample_by_id_variable_rows(indexed_column) -%}
    {% set foreign_table_schema = "raw_prod" %}
    {% set sample_target_output = "sample-dev" %}

    {% do log("Variable sample_size_ratio: " ~ var("sample_size_ratio"), info=True) %}
    {% do log("Target database: " ~ var("sample_size_ratio"), info=True) %}
    {% do log("Target schema: " ~ var("sample_size_ratio"), info=True) %}

    {% if target.name != sample_target_output %}
        {{
            log(
                "Skipping sample table creation because target is not "
                ~ sample_target_output,
                info=True,
            )
        }}
        {% do return(None) %}
    {% endif %}

    {% set sources = [] %}
    {% set sources_row_counts = {} %}

    {% do log("Scanning all the sources in dbt project", info=True) %}

    {% for node in graph.sources.values() %}
        {% do sources.append(node.name) %}

        {% do log("Source: " ~ node.unique_id, info=True) %}

        {% set current_row_count_query %}
            select count(*) as row_count from {{ foreign_table_schema }}.{{ node.name }}
        {% endset %}

        {% set results = run_query(current_row_count_query) %}

        {% set row_count = results.columns[0].values()[0] | as_number %}

        {% do sources_row_counts.update({node.name: row_count}) %}

    {% endfor %}

    {% do log("Dropping target schema " ~ target.schema ~ " if exists...", info=True) %}

    {% set drop_schema_sql %}
        DROP SCHEMA IF EXISTS {{target.schema}} CASCADE;
        CREATE SCHEMA IF NOT EXISTS {{target.schema}};
    {% endset %}

    {% do run_query(drop_schema_sql) %}

    {%- for source in sources -%}
        {% set sampled_row_count = [
            (sources_row_counts[source] * var("sample_size_ratio"))
            | round
            | int,
            5,
        ] | max %}

        {% do log("Creating sampled table " ~ source ~ "...", info=True) %}

        {% do log(
            "Row count: "
            ~ sources_row_counts[source]
            ~ " | Sampled row count: "
            ~ sampled_row_count,
            info=True,
        ) %}

        {% set drop_table_sql %}
            DROP TABLE IF EXISTS {{target.schema}}.{{ source }};
        {% endset %}

        {% do run_query(drop_table_sql) %}

        {% set create_sql %}
            CREATE TABLE {{target.schema}}.{{ source }}  AS
            WITH RANDOMISED AS (
                SELECT {{indexed_column}}, RANDOM() AS rand_rn
                FROM {{foreign_table_schema}}.{{ source }}
            )
            SELECT *
            FROM {{foreign_table_schema}}.{{ source }}
            WHERE {{indexed_column}} IN (
                SELECT {{indexed_column}}
                FROM RANDOMISED
                ORDER BY rand_rn
                LIMIT {{ sampled_row_count }}
                )

        {% endset %}

        {% do run_query(create_sql) %}

        {% do log(
            "Sampled table "
            ~ target.schema
            ~ "."
            ~ source
            ~ " is created! Rejoice!",
            info=True,
        ) %}

    {%- endfor -%}

{%- endmacro %}

{#
TO DO: implement relationships between sampled tables (e.g. customer ids sample, should exist in customer_addresses sample)
 #}


{#
    Renders a schema name given a custom schema name. In production, this macro
    will render out the overriden schema name for a model. In dev, it will create a 
    schema dev_<developer_name>

    Arguments:
    custom_schema_name: The custom schema name specified for a model, or none
    node: The node the schema is being generated for

#}

{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- set default_schema = target.schema -%}
    {%- if target.name == 'prod' and custom_schema_name is not none -%}

        {{ custom_schema_name | trim }}

    {%- else -%}

        {{ default_schema }}

    {%- endif -%}

{%- endmacro %}
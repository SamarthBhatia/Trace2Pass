"""
Trace2Pass Collector - JSON Schemas

Marshmallow schemas for validating incoming anomaly reports.
"""

from marshmallow import Schema, fields, validate, ValidationError, INCLUDE


class LocationSchema(Schema):
    """Schema for source code location."""
    file = fields.Str(required=True)
    line = fields.Int(required=True, validate=validate.Range(min=0))  # Allow 0 when metadata unavailable
    function = fields.Str(required=True)


class CompilerSchema(Schema):
    """Schema for compiler information."""
    name = fields.Str(required=True, validate=validate.OneOf(['clang', 'gcc', 'msvc', 'unknown']))
    version = fields.Str(required=True)
    target = fields.Str(required=False)


class BuildInfoSchema(Schema):
    """Schema for build configuration."""
    optimization_level = fields.Str(required=True, validate=validate.OneOf(['-O0', '-O1', '-O2', '-O3', '-Os', '-Oz', 'unknown']))
    flags = fields.List(fields.Str(), required=False)
    source_hash = fields.Str(required=False)
    binary_checksum = fields.Str(required=False)


class SystemInfoSchema(Schema):
    """Schema for system information."""
    os = fields.Str(required=False)
    arch = fields.Str(required=False)
    hostname = fields.Str(required=False)


class CheckDetailsSchema(Schema):
    """Schema for check-specific details (flexible)."""
    class Meta:
        # Allow additional fields not defined in schema
        unknown = INCLUDE


class ReportSchema(Schema):
    """Schema for anomaly report."""
    report_id = fields.Str(required=True)
    timestamp = fields.DateTime(required=True)
    check_type = fields.Str(
        required=True,
        validate=validate.OneOf([
            'arithmetic_overflow',
            'unreachable_code_executed',
            'division_by_zero',
            'pure_function_inconsistency',
            'sign_conversion',
            'bounds_violation',
            'loop_bound_exceeded'
        ])
    )
    location = fields.Nested(LocationSchema, required=True)
    pc = fields.Str(required=False)
    stacktrace = fields.List(fields.Str(), required=False)
    compiler = fields.Nested(CompilerSchema, required=True)
    build_info = fields.Nested(BuildInfoSchema, required=True)
    check_details = fields.Nested(CheckDetailsSchema, required=False)
    system_info = fields.Nested(SystemInfoSchema, required=False)


# Create schema instances
report_schema = ReportSchema()

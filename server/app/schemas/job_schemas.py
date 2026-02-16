"""
Job/Requisition Schemas for validation
"""
from marshmallow import Schema, fields, ValidationError, EXCLUDE, validates_schema, pre_load
from marshmallow.validate import Range, Length, OneOf


class KnockoutRuleSchema(Schema):
    """Schema for a single knockout rule."""

    type = fields.Str(
        required=True,
        validate=OneOf([
            "certification",
            "experience",
            "skills",
            "education",
            "location",
            "salary",
        ]),
    )
    field = fields.Str(required=True)
    operator = fields.Str(
        required=True,
        validate=OneOf([">=", ">", "==", "!=", "<", "<="]),
    )
    value = fields.Raw(required=True)


class JobBaseSchema(Schema):
    """Base job schema with common fields"""

    title = fields.Str(required=True, validate=Length(min=1, max=200))
    description = fields.Str(required=True)
    company = fields.Str(
        allow_none=True,
        load_default="",
        dump_default=""
    )
    location = fields.Str(
        allow_none=True,
        load_default="",
        dump_default=""
    )
    salary_min = fields.Float(
        allow_none=True,
        load_default=None,
        dump_default=None,
        validate=Range(min=0)
    )
    salary_max = fields.Float(
        allow_none=True,
        load_default=None,
        dump_default=None,
        validate=Range(min=0)
    )
    salary_currency = fields.Str(
        allow_none=True,
        load_default="ZAR",
        dump_default="ZAR"
    )
    salary_period = fields.Str(
        allow_none=True,
        load_default="monthly",
        dump_default="monthly",
        validate=OneOf(["monthly", "yearly"])
    )

    job_summary = fields.Str(
        allow_none=True,
        load_default="",
        dump_default=""
    )

    employment_type = fields.Str(
        load_default="full_time",
        dump_default="full_time",
        validate=OneOf(["full_time", "part_time", "contract", "internship"])
    )

    responsibilities = fields.List(
        fields.Str(),
        load_default=list,
        dump_default=list
    )

    company_details = fields.Str(
        allow_none=True,
        load_default="",
        dump_default=""
    )

    qualifications = fields.List(
        fields.Str(),
        load_default=list,
        dump_default=list
    )

    category = fields.Str(
        allow_none=True,
        load_default="",
        dump_default=""
    )

    required_skills = fields.List(
        fields.Str(),
        load_default=list,
        dump_default=list
    )

    min_experience = fields.Float(
        load_default=0.0,
        dump_default=0.0,
        validate=Range(min=0)
    )

    knockout_rules = fields.List(
        fields.Nested(KnockoutRuleSchema),
        load_default=list,
        dump_default=list
    )

    weightings = fields.Dict(
        load_default=lambda: {
            "cv": 60,
            "assessment": 40,
            "interview": 0,
            "references": 0,
        },
        dump_default=lambda: {
            "cv": 60,
            "assessment": 40,
            "interview": 0,
            "references": 0,
        }
    )

    assessment_pack = fields.Dict(
        load_default=lambda: {"questions": []},
        dump_default=lambda: {"questions": []}
    )

    vacancy = fields.Int(
        load_default=1,
        dump_default=1,
        validate=Range(min=1)
    )

    # Display fields for job listing
    location = fields.Str(allow_none=True, load_default="", dump_default="")
    employment_type = fields.Str(allow_none=True, load_default="Full Time", dump_default="Full Time")
    salary_range = fields.Str(allow_none=True, load_default="", dump_default="")
    application_deadline = fields.DateTime(allow_none=True, load_default=None)
    company = fields.Str(allow_none=True, load_default="", dump_default="")
    banner = fields.Str(allow_none=True)

    class Meta:
        unknown = EXCLUDE

    @pre_load
    def normalize_knockout_rules(self, data, **kwargs):
        rules = data.get("knockout_rules")
        if isinstance(rules, list) and rules and not isinstance(rules[0], dict):
            data["knockout_rules"] = [
                {
                    "type": "skills",
                    "field": "skills",
                    "operator": "==",
                    "value": str(rule)
                }
                for rule in rules
            ]
        currency = data.get("salary_currency")
        if currency is None or (isinstance(currency, str) and not currency.strip()):
            data["salary_currency"] = "ZAR"
        period = data.get("salary_period")
        if period is None or (isinstance(period, str) and not period.strip()):
            data["salary_period"] = "monthly"
        return data


class JobCreateSchema(JobBaseSchema):
    """Schema for job creation"""

    @validates_schema
    def validate_assessment_pack(self, data, **kwargs):
        assessment_pack = data.get("assessment_pack", {})

        if not isinstance(assessment_pack, dict):
            raise ValidationError("assessment_pack must be a dictionary")

        if "questions" not in assessment_pack:
            raise ValidationError("assessment_pack must contain 'questions' key")

        if not isinstance(assessment_pack["questions"], list):
            raise ValidationError("assessment_pack.questions must be a list")

    @validates_schema
    def validate_weightings(self, data, **kwargs):
        weightings = data.get("weightings", {})

        if not isinstance(weightings, dict):
            raise ValidationError("weightings must be a dictionary")

        for key, value in weightings.items():
            if not isinstance(value, (int, float)):
                raise ValidationError(f"weightings[{key}] must be a number")

        total = sum(weightings.values())
        if abs(total - 100) > 0.001:
            raise ValidationError("Weightings must sum to 100")


class JobUpdateSchema(Schema):
    """Schema for job updates (partial updates allowed)"""

    title = fields.Str(validate=Length(min=1, max=200))
    description = fields.Str()
    company = fields.Str(allow_none=True)
    location = fields.Str(allow_none=True)
    salary_min = fields.Float(allow_none=True, validate=Range(min=0))
    salary_max = fields.Float(allow_none=True, validate=Range(min=0))
    salary_currency = fields.Str(allow_none=True)
    salary_period = fields.Str(allow_none=True)
    job_summary = fields.Str(allow_none=True)
    responsibilities = fields.List(fields.Str())
    company_details = fields.Str(allow_none=True)
    qualifications = fields.List(fields.Str())
    category = fields.Str(allow_none=True)
    required_skills = fields.List(fields.Str())
    min_experience = fields.Float(validate=Range(min=0))
    knockout_rules = fields.List(fields.Nested(KnockoutRuleSchema))
    weightings = fields.Dict()
    assessment_pack = fields.Dict()
    vacancy = fields.Int(validate=Range(min=1))
    is_active = fields.Bool()

    class Meta:
        unknown = EXCLUDE

    @validates_schema
    def validate_weightings(self, data, **kwargs):
        if "weightings" in data:
            weightings = data["weightings"]

            if not isinstance(weightings, dict):
                raise ValidationError("weightings must be a dictionary")

            for key, value in weightings.items():
                if not isinstance(value, (int, float)):
                    raise ValidationError(f"weightings[{key}] must be a number")

            total = sum(weightings.values())
            if abs(total - 100) > 0.001:
                raise ValidationError("Weightings must sum to 100")


class JobResponseSchema(JobBaseSchema):
    """Schema for job responses"""

    id = fields.Int()
    created_by = fields.Int()
    created_at = fields.DateTime()
    updated_at = fields.DateTime()
    published_on = fields.DateTime()
    is_active = fields.Bool()
    deleted_at = fields.DateTime(allow_none=True)

    application_count = fields.Int(
        dump_only=True,
        dump_default=0
    )

    statistics = fields.Dict(
        dump_only=True,
        dump_default=dict
    )


class JobListSchema(Schema):
    """Schema for job list responses"""

    jobs = fields.List(fields.Nested(JobResponseSchema))
    pagination = fields.Dict()
    filters = fields.Dict()


class JobFilterSchema(Schema):
    """Schema for job filtering query parameters"""

    page = fields.Int(load_default=1, validate=Range(min=1))
    per_page = fields.Int(load_default=20, validate=Range(min=1, max=100))
    category = fields.Str(allow_none=True)
    status = fields.Str(
        load_default="active",
        validate=OneOf(["active", "inactive", "all"])
    )
    sort_by = fields.Str(
        load_default="created_at",
        validate=OneOf([
            "created_at",
            "updated_at",
            "title",
            "category",
            "min_experience",
            "vacancy"
        ])
    )
    sort_order = fields.Str(
        load_default="desc",
        validate=OneOf(["asc", "desc"])
    )
    search = fields.Str(allow_none=True)


class JobActivityLogSchema(Schema):
    """Schema for job activity log"""

    id = fields.Int(dump_only=True)
    job_id = fields.Int()
    user_id = fields.Int()
    user_name = fields.Str(dump_only=True)
    user_email = fields.Str(dump_only=True)
    action = fields.Str(
        validate=OneOf([
            "CREATE",
            "UPDATE",
            "DELETE",
            "VIEW",
            "VIEW_DETAILED",
            "RESTORE"
        ])
    )
    details = fields.Dict()
    ip_address = fields.Str(allow_none=True)
    user_agent = fields.Str(allow_none=True)
    timestamp = fields.DateTime(dump_only=True)


class JobActivityFilterSchema(Schema):
    """Schema for job activity filter query parameters"""

    page = fields.Int(load_default=1, validate=Range(min=1))
    per_page = fields.Int(load_default=50, validate=Range(min=1, max=100))


# Initialize schemas
job_create_schema = JobCreateSchema()
job_update_schema = JobUpdateSchema()
job_response_schema = JobResponseSchema()
job_list_schema = JobListSchema()
job_filter_schema = JobFilterSchema()
job_activity_log_schema = JobActivityLogSchema()
job_activity_filter_schema = JobActivityFilterSchema()

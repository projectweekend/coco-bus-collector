variable "CTA_BUS_API_KEY" {}
variable "CTA_BUS_PREDICTION_ROUTE" {}


provider "aws" {
    profile = "default"
    region = "us-east-1"
}


data "terraform_remote_state" "coco_tfstate" {
    backend = "s3"
    config {
        bucket = "pw-terraform-state"
        key = "coco-bus-collector/terraform.tfstate"
        profile = "default"
        region = "us-east-1"
    }
}


data "aws_iam_policy_document" "coco_lambda_assume_role_policy" {
    statement {
        actions = [ "sts:AssumeRole" ]
        principals {
            type = "Service"
            identifiers = [ "lambda.amazonaws.com" ]
        }
    }
}


data "aws_iam_policy_document" "coco_lambda_iam_policy" {
    statement {
        effect = "Allow"
        actions = [
            "dynamodb:PutItem",
        ]
        resources = [
            "${aws_dynamodb_table.coco_bustracker_dynamodb_table.arn}",
        ]
    }
    statement {
        effect = "Allow"
        actions = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ]
        resources = [
            "*",
        ]
    }
}


resource "aws_iam_policy" "coco_lambda_iam_policy" {
    name = "coco_bustracker_lambda_policy"
    policy = "${data.aws_iam_policy_document.coco_lambda_iam_policy.json}"
}


resource "aws_iam_role" "coco_bustracker_lambda_iam_role" {
    name = "coco_bustracker_lambda"
    assume_role_policy = "${data.aws_iam_policy_document.coco_lambda_assume_role_policy.json}"
}


resource "aws_iam_role_policy_attachment" "coco_lambda_iam_policy_attach" {
    role = "${aws_iam_role.coco_bustracker_lambda_iam_role.name}"
    policy_arn = "${aws_iam_policy.coco_lambda_iam_policy.arn}"
}


resource "aws_dynamodb_table" "coco_bustracker_dynamodb_table" {
    name = "coco_bustracker"
    read_capacity = 1
    write_capacity = 2
    hash_key = "stop_id"
    range_key = "current_time"
    attribute {
        name = "stop_id"
        type = "S"
    }
    attribute {
        name = "current_time"
        type = "N"
    }
}


resource "aws_lambda_function" "coco_bustracker_lambda_17772" {
    filename = "lambda.zip"
    function_name = "coco_bustracker_stop_17772"
    role = "${aws_iam_role.coco_bustracker_lambda_iam_role.arn}"
    handler = "main.lambda_handler"
    runtime = "python2.7"
    timeout = 10
    source_code_hash = "${base64sha256(file("lambda.zip"))}"
    environment {
        variables = {
            CTA_BUS_API_KEY = "${var.CTA_BUS_API_KEY}"
            CTA_BUS_PREDICTION_ROUTE = "${var.CTA_BUS_PREDICTION_ROUTE}"
            CTA_BUS_STOP_ID = "17772"
            DYNAMODB_TABLE = "${aws_dynamodb_table.coco_bustracker_dynamodb_table.name}"
        }
    }
}


resource "aws_cloudwatch_event_rule" "coco_every_5_minutes" {
    name = "coco_every_5_minute"
    schedule_expression = "rate(5 minutes)"
}


resource "aws_cloudwatch_event_target" "coco_bustracker_lambda_17772_sched" {
    rule = "${aws_cloudwatch_event_rule.coco_every_5_minutes.name}"
    arn = "${aws_lambda_function.coco_bustracker_lambda_17772.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_coco_bustracker_lambda_17772" {
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.coco_bustracker_lambda_17772.function_name}"
    principal = "events.amazonaws.com"
    source_arn = "${aws_cloudwatch_event_rule.coco_every_5_minutes.arn}"
}

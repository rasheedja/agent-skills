# Skill: AWS CLI — finding CloudFormation failure reasons and useful query patterns

This skill covers using the AWS CLI to inspect CloudFormation stack events (e.g. after a failed deploy) and other practical query patterns. For **debugging failed deployments** (interpreting rollback, root cause, service-specific gotchas), see **skill-debugging-aws.md**.

**Prerequisites:** AWS CLI installed and authenticated (`aws sts get-caller-identity` works). You need permissions to call `cloudformation:DescribeStackEvents` (and other read APIs you use).

---

## 1. Get the real reason a CloudFormation update failed

When a stack goes to `UPDATE_ROLLBACK_COMPLETE` (or a create fails), the **CI log or deploy output often only shows the final stack state**, not which resource failed or why. The actual failure is in **stack events**.

### 1.1 Filter for failed events

```bash
aws cloudformation describe-stack-events \
  --stack-name <STACK_NAME> \
  --region <REGION> \
  --query "StackEvents[?ResourceStatus=='UPDATE_FAILED' || ResourceStatus=='CREATE_FAILED'].{Resource:LogicalResourceId,Status:ResourceStatus,Reason:ResourceStatusReason,Time:Timestamp}" \
  --output table
```

- Replace `<STACK_NAME>` (e.g. `preprod-realfi-stable`) and `<REGION>` (e.g. `us-east-2`).
- **Reason** is the important field: it contains the service error message (e.g. validation error, permission denied, resource limit).
- **First row** in the table is usually the resource that failed first; later rows are often "Resource update cancelled" (cascade from the initial failure).

### 1.2 Same query, JSON output

For scripting or copying the exact error text:

```bash
aws cloudformation describe-stack-events \
  --stack-name <STACK_NAME> \
  --region <REGION> \
  --query "StackEvents[?ResourceStatus=='UPDATE_FAILED' || ResourceStatus=='CREATE_FAILED'].{Resource:LogicalResourceId,Reason:ResourceStatusReason}" \
  --output json
```

### 1.3 Limit number of events (optional)

Stack events are ordered by timestamp (newest first). To avoid huge output, use `--max-items`:

```bash
aws cloudformation describe-stack-events \
  --stack-name <STACK_NAME> \
  --region <REGION> \
  --max-items 30 \
  --query "StackEvents[?ResourceStatus=='UPDATE_FAILED' || ResourceStatus=='CREATE_FAILED'].{Resource:LogicalResourceId,Reason:ResourceStatusReason}" \
  --output table
```

---

## 2. Query syntax (JMESPath) quick reference

- **Filter arrays:** `StackEvents[?ResourceStatus=='CREATE_FAILED']` — keep only elements where `ResourceStatus` equals the string.
- **Multiple conditions:** Use `||` (or) or `&&` (and), e.g. `?ResourceStatus=='UPDATE_FAILED' || ResourceStatus=='CREATE_FAILED'`.
- **Project to a smaller object:** `.{Resource:LogicalResourceId,Reason:ResourceStatusReason}` — output only those keys, with optional new names (e.g. `Resource` instead of `LogicalResourceId`).
- **Output:** `--output table` for human-readable; `--output json` for parsing or copying.

---

## 3. Other useful patterns

- **List stacks:** `aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE UPDATE_ROLLBACK_COMPLETE --query "StackSummaries[*].{Name:StackName,Status:StackStatus}" --output table`
- **Describe a single stack (parameters, outputs):** `aws cloudformation describe-stacks --stack-name <STACK_NAME> --region <REGION>`
- **Check login:** `aws sts get-caller-identity` — confirms which account and identity you’re using.

---

## 4. Quick reference: "deploy failed, what broke?"

1. Run the command in §1.1 with your stack name and region.
2. Find the row whose **Reason** is **not** "Resource update cancelled" — that’s the root cause.
3. Use that **Resource** (logical ID) and **Reason** (error message) to fix the template or permissions; see **skill-debugging-aws.md** for common causes and service-specific rules.

---

## 5. DynamoDB Kinesis streaming destination (check / disable)

When a table fails with "not in a valid state to enable Kinesis Streaming Destination", the table already has a destination that must be **DISABLED** before CloudFormation can enable the one in your template.

**Check current destination(s) and status:**

```bash
aws dynamodb describe-kinesis-streaming-destination \
  --table-name <TABLE_NAME> \
  --region <REGION>
```

- Replace `<TABLE_NAME>` (e.g. `preprod-realfi--supply-2`) and `<REGION>`.
- Response includes `KinesisDataStreamDestinations` with each `StreamArn` and `DestinationStatus` (e.g. ACTIVE, ENABLING, DISABLED, ENABLE_FAILED).

**Disable a destination (so the stack can enable the stream defined in code):**

```bash
aws dynamodb disable-kinesis-streaming-destination \
  --table-name <TABLE_NAME> \
  --stream-arn <STREAM_ARN> \
  --region <REGION>
```

- Use the **StreamArn** from the describe output. After the destination reaches **DISABLED**, re-run the CloudFormation update.

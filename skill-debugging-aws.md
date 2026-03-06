# Skill: Debugging AWS issues — failed deployments, rollback, and service gotchas

This skill covers how to find the **root cause** when an AWS deployment fails (e.g. CloudFormation rollback) and some **service-specific gotchas** that cause hard-to-spot failures. For the **exact AWS CLI commands** to get failure reasons from stack events, see **skill-aws-cli.md**.

**Prerequisites:** AWS CLI authenticated. You need `cloudformation:DescribeStackEvents` (and any other read APIs for the resources you’re debugging).

---

## 1. CI / deploy log often doesn’t show the real error

When a CloudFormation update fails and the stack rolls back to `UPDATE_ROLLBACK_COMPLETE`:

- The **deploy step** (e.g. GitHub Actions) often only sees the **final stack state** (e.g. "stack is UPDATE_ROLLBACK_COMPLETE") and reports that as the failure.
- The **underlying resource failure** (which logical resource failed and the exact error message) is **not** in the CI log; it lives in **CloudFormation stack events** in AWS.

So: **always use stack events** to get the real reason. See **skill-aws-cli.md** §1 for the `describe-stack-events` command and query.

---

## 2. Interpreting stack events: root cause vs cascade

After running the command in **skill-aws-cli.md** §1.1, you’ll see several rows if multiple resources “failed”:

- **Root cause:** The row whose **Reason** is the **actual error** from the service (e.g. "Dynamic Partitioning Namespaces can't be part of an error prefix expression", "Access Denied", "Resource already exists"). That’s the one to fix.
- **Cascade:** Other rows often show **"Resource update cancelled"**. That means CloudFormation cancelled their update because **another** resource failed first. Fix the root cause; those will succeed on the next deploy.

So: **ignore "Resource update cancelled"** when looking for what to fix; find the row with the **specific service error message**.

---

## 3. Service-specific gotchas

### 3.1 Kinesis Data Firehose — ErrorOutputPrefix

- **Rule:** In **ErrorOutputPrefix** (where failed/delivery-failed records are written), you **cannot** use **dynamic partitioning namespaces** such as `!{partitionKeyFromQuery:...}` or `!{partitionKeyFromLambda:...}`.
- **Error you’ll see:** `"Dynamic Partitioning Namespaces can't be part of an error prefix expression"` (CREATE_FAILED or UPDATE_FAILED on the delivery stream).
- **Fix:** Use only allowed placeholders in the error prefix, e.g. `!{firehose:error-output-type}` and `!{timestamp:yyyy}-!{timestamp:mm}-!{timestamp:dd}`. Do **not** put `!{partitionKeyFromQuery:tableName}` (or any other partition key) in **ErrorOutputPrefix**. The **main Prefix** (success path) is where partition keys are intended and allowed.

### 3.2 Cross-account S3 / KMS (e.g. Firehose to another account’s bucket)

- If the delivery target (S3 bucket or KMS key) is in a **different AWS account**, the **bucket policy** and **KMS key policy** in that account must **allow** the role (or service principal) from the **deploying account**. Otherwise create or runtime delivery can fail with access denied.
- When debugging, check stack events for the failing resource; if the message mentions access denied or KMS, verify the target account’s policies.

### 3.3 DynamoDB — Kinesis Data Streams for DynamoDB

- Adding **KinesisStreamSpecification** to a table (native DynamoDB → Kinesis CDC) requires the **Kinesis stream to already exist** in the same account and region. In CloudFormation, use **DependsOn** on the stream so the table is updated only after the stream is created.
- If the stream name already exists (e.g. left over from a previous rollback), stream **create** will fail; delete the existing stream or use a different name.

### 3.4 DynamoDB — Kinesis streaming destination already enabled

- **Error you’ll see:** `"Table is not in a valid state to enable Kinesis Streaming Destination: EnableKinesisStreamingDestination must be DISABLED or ENABLE_FAILED to perform ENABLE operation."` (UPDATE_FAILED on the table.)
- **Cause:** The table already has a Kinesis streaming destination in a state other than DISABLED or ENABLE_FAILED (e.g. **ACTIVE**, **ENABLING**, or orphaned after a rollback that deleted the stream). CloudFormation is trying to run “enable” again; DynamoDB only allows enable when the destination is DISABLED or ENABLE_FAILED.
- **Fix:** No template change needed. **Disable the existing destination** in AWS (console or CLI), then re-run the stack update. Use `describe-kinesis-streaming-destination` to see the current stream ARN and status; use `disable-kinesis-streaming-destination` with that stream ARN and the table name. After the destination is DISABLED, the next deploy can enable the stream defined in code. See **skill-aws-cli.md** §5 for the commands.

---

## 4. Quick reference: "deploy failed" checklist

1. **Get failure reason:** Run the command in **skill-aws-cli.md** §1.1 with your stack name and region.
2. **Identify root cause:** In the output, find the row whose **Reason** is **not** "Resource update cancelled".
3. **Map to fix:**
   - Firehose "error prefix" / "Dynamic Partitioning Namespaces" → remove `partitionKeyFromQuery` / `partitionKeyFromLambda` from **ErrorOutputPrefix** (see §3.1).
   - Access denied / KMS → check bucket and key policies in the target account (see §3.2).
   - Resource already exists → delete the conflicting resource or change the name in the template (see §3.3).
   - DynamoDB "not in a valid state to enable Kinesis Streaming Destination" → disable the existing Kinesis destination on the table (see §3.4 and **skill-aws-cli.md** §5), then redeploy.
4. **Fix template or policies** (or clear the conflicting state in AWS), then redeploy.

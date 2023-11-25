# Challenge

## How to use

Terraform returns an output that contain DNS names for all candidates.
That DNS name should be used by candidates and reviewers.

### For a candidate
```
ssh $DNS_NAME -l ubuntu
```

### For a reviewer
```
ssh $DNS_NAME -l tk -i ~/.ssh/gini-dev
```

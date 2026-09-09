enum JobStatus { pending, funded, done, disputed }

class Job {
  final String title;
  final int amount;
  JobStatus status;
  Job({
    required this.title,
    required this.amount,
    this.status = JobStatus.pending,
  });
}

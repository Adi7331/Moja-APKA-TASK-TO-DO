package com.example.dzien_po_dniu

import java.time.LocalDateTime

internal data class TaskDigestEntry(
    val id: String,
    val title: String,
    val status: String,
    val dueAt: LocalDateTime?,
)

internal fun tasksForDigest(
    tasks: Iterable<TaskDigestEntry>,
    now: LocalDateTime,
): List<TaskDigestEntry> {
    val latestById = linkedMapOf<String, TaskDigestEntry>()
    tasks.forEach { latestById[it.id] = it }
    val tomorrow = now.toLocalDate().plusDays(1).atStartOfDay()
    return latestById.values
        .filter { it.status != "done" && it.dueAt?.isBefore(tomorrow) == true }
        .sortedBy { it.dueAt }
}

internal fun nextDigestOccurrence(
    now: LocalDateTime,
    interval: Int,
    start: Int,
    end: Int,
): LocalDateTime? {
    if (start == end || interval !in 15..1440) return null
    if (start !in 0 until 24 * 60 || end !in 0 until 24 * 60) return null
    val nowMinute = now.hour * 60 + now.minute
    val crossesMidnight = end < start
    val firstOffset = if (crossesMidnight && nowMinute < end) -1 else 0
    for (offset in firstOffset..32) {
        val date = now.toLocalDate().plusDays(offset.toLong())
        val begin = date.atStartOfDay().plusMinutes(start.toLong())
        val endDate = if (crossesMidnight) date.plusDays(1) else date
        val stop = endDate.atStartOfDay().plusMinutes(end.toLong())
        var candidate = begin
        while (candidate.isBefore(stop)) {
            if (candidate.isAfter(now)) return candidate
            candidate = candidate.plusMinutes(interval.toLong())
        }
    }
    return null
}

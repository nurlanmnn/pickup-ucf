interface TitleParams {
  sport: string;
  custom_sport?: string;
  address?: string;
  starts_at: string;
  ends_at: string;
  capacity?: number;
  equipment_needed?: boolean;
  positions?: string[];
}

export function makeTitle({
  sport,
  custom_sport,
  address,
  starts_at,
  ends_at,
  capacity,
  equipment_needed,
  positions
}: TitleParams): string {
  // Use custom sport if provided, otherwise use the sport
  const sportName = custom_sport || sport;
  
  // Format time (e.g., "Today 7pm")
  const start = new Date(starts_at);
  const end = new Date(ends_at);
  const now = new Date();
  
  let timeStr = '';
  if (start.toDateString() === now.toDateString()) {
    timeStr = `Today ${start.toLocaleTimeString('en-US', { hour: 'numeric', minute: start.getMinutes() > 0 ? '2-digit' : undefined })}`;
  } else {
    timeStr = start.toLocaleDateString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: start.getMinutes() > 0 ? '2-digit' : undefined });
  }
  
  // Add end time if different day or significant duration
  const durationMs = end.getTime() - start.getTime();
  if (durationMs > 60 * 60 * 1000) { // > 1 hour
    timeStr += `-${end.toLocaleTimeString('en-US', { hour: 'numeric', minute: end.getMinutes() > 0 ? '2-digit' : undefined })}`;
  }
  
  // Build title parts
  const parts = [sportName];
  
  if (address) {
    parts.push(`@ ${address}`);
  }
  
  parts.push(`| ${timeStr}`);
  
  if (positions && positions.length > 0) {
    parts.push(`• Need ${positions.join(', ')}`);
  }
  
  if (equipment_needed) {
    parts.push('• Bring equipment');
  }
  
  if (capacity) {
    parts.push(`(cap ${capacity})`);
  }
  
  return parts.join(' ');
}

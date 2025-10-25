export const UCF_VENUES = [
  { key: 'im_fields', name: 'IM Fields' },
  { key: 'im_basketball', name: 'IM Basketball Courts' },
  { key: 'im_racquetball', name: 'IM Racquetball Courts' },
  { key: 'im_soccer', name: 'RWC Park' },
  { key: 'rcc_volleyball', name: 'RWC Volleyball Courts' },
  { key: 'lake_claire', name: 'Lake Claire' },
  { key: 'memory_mall', name: 'Memory Mall' },
  { key: 'arc_fitness', name: 'RWC Fitness' },
  { key: 'other', name: 'Other' },
];

export function getVenueName(key: string): string {
  return UCF_VENUES.find(v => v.key === key)?.name || key;
}

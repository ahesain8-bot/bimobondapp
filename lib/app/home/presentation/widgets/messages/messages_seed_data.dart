List<Map<String, dynamic>> messagesSeedChats() => [
  {
    'name': 'Sarah Ahmed',
    'messageKey': 'property',
    'time': '2m',
    'unread': true,
    'active': true,
  },
  {
    'name': 'Mohammed Khalid',
    'messageKey': 'offer',
    'time': '1h',
    'unread': false,
    'active': false,
  },
  {
    'name': 'Invest Team',
    'messageKey': 'thanks',
    'time': '3h',
    'unread': true,
    'active': false,
  },
  {
    'name': 'Laila Ali',
    'messageKey': 'car',
    'time': '5h',
    'unread': false,
    'active': true,
  },
];

List<Map<String, dynamic>> messagesSeedMentions() => [
  {
    'userId': 'mention-user-1',
    'user': 'Omar Design',
    'contentKey': 'villa',
    'time': '10m',
    'postPreview': 'https://picsum.photos/100/100?random=1',
  },
  {
    'userId': 'mention-user-2',
    'user': 'Realty Expert',
    'contentKey': 'check',
    'time': '2h',
    'postPreview': 'https://picsum.photos/100/100?random=2',
  },
];

List<Map<String, dynamic>> messagesSeedSuggestions() => [
  {
    'userId': 'suggestion-user-1',
    'name': 'Ahmed Modern',
    'bioKey': 'designer',
    'isFollowing': false,
  },
  {
    'userId': 'suggestion-user-2',
    'name': 'Jeddah Homes',
    'bioKey': 'jeddah',
    'isFollowing': false,
  },
  {
    'userId': 'suggestion-user-3',
    'name': 'Luxury Living',
    'bioKey': 'luxury',
    'isFollowing': false,
  },
];

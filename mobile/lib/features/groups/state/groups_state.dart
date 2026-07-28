import '../domain/group_models.dart';

enum GroupsStatus { loading, ready, error }

class GroupsState {
  const GroupsState({
    required this.status,
    this.groups = const [],
    this.errorMessage,
    this.isRefreshing = false,
    this.isCreating = false,
  });

  const GroupsState.loading() : this(status: GroupsStatus.loading);

  final GroupsStatus status;
  final List<AppGroup> groups;
  final String? errorMessage;
  final bool isRefreshing;
  final bool isCreating;

  bool get isEmpty => status == GroupsStatus.ready && groups.isEmpty;

  GroupsState copyWith({
    GroupsStatus? status,
    List<AppGroup>? groups,
    String? errorMessage,
    bool? isRefreshing,
    bool? isCreating,
    bool clearErrorMessage = false,
  }) {
    return GroupsState(
      status: status ?? this.status,
      groups: groups ?? this.groups,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isCreating: isCreating ?? this.isCreating,
    );
  }
}

enum GroupDetailStatus { loading, ready, unavailable, error }

class GroupDetailState {
  const GroupDetailState({
    required this.status,
    this.group,
    this.members = const [],
    this.errorMessage,
    this.isAddingGuest = false,
  });

  const GroupDetailState.loading() : this(status: GroupDetailStatus.loading);

  final GroupDetailStatus status;
  final AppGroup? group;
  final List<GroupMember> members;
  final String? errorMessage;
  final bool isAddingGuest;

  GroupDetailState copyWith({
    GroupDetailStatus? status,
    AppGroup? group,
    List<GroupMember>? members,
    String? errorMessage,
    bool? isAddingGuest,
    bool clearErrorMessage = false,
  }) {
    return GroupDetailState(
      status: status ?? this.status,
      group: group ?? this.group,
      members: members ?? this.members,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      isAddingGuest: isAddingGuest ?? this.isAddingGuest,
    );
  }
}

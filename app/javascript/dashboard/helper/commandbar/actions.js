import { emitter } from 'shared/helpers/mitt';

import {
  CMD_MUTE_CONVERSATION,
  CMD_SEND_TRANSCRIPT,
  CMD_UNMUTE_CONVERSATION,
} from 'dashboard/helper/commandbar/events';

import {
  ICON_MUTE_CONVERSATION,
  ICON_SEND_TRANSCRIPT,
  ICON_UNMUTE_CONVERSATION,
} from 'dashboard/helper/commandbar/icons';

export const SEND_TRANSCRIPT_ACTION = {
  id: 'send_transcript',
  title: 'COMMAND_BAR.COMMANDS.SEND_TRANSCRIPT',
  section: 'COMMAND_BAR.SECTIONS.CONVERSATION',
  icon: ICON_SEND_TRANSCRIPT,
  handler: () => emitter.emit(CMD_SEND_TRANSCRIPT),
};

export const UNMUTE_ACTION = {
  id: 'unmute_conversation',
  title: 'COMMAND_BAR.COMMANDS.UNMUTE_CONVERSATION',
  section: 'COMMAND_BAR.SECTIONS.CONVERSATION',
  icon: ICON_UNMUTE_CONVERSATION,
  handler: () => emitter.emit(CMD_UNMUTE_CONVERSATION),
};

export const MUTE_ACTION = {
  id: 'mute_conversation',
  title: 'COMMAND_BAR.COMMANDS.MUTE_CONVERSATION',
  section: 'COMMAND_BAR.SECTIONS.CONVERSATION',
  icon: ICON_MUTE_CONVERSATION,
  handler: () => emitter.emit(CMD_MUTE_CONVERSATION),
};

import axios from 'axios';
import { actions } from '../../conversationUnreadCounts';
import types from '../../../mutation-types';

const commit = vi.fn();
global.axios = axios;
vi.mock('axios');

describe('#actions', () => {
  beforeEach(() => {
    commit.mockClear();
    axios.get.mockReset();
  });

  describe('#get', () => {
    it('commits unread counts when API is successful', async () => {
      const payload = {
        all_count: 2,
        archived_count: 1,
        inboxes: { 1: '2' },
        labels: { 3: 4 },
        teams: { 5: 6 },
        mentions_count: 7,
        participating_count: 8,
        unattended_count: 9,
        folders: { 10: 11 },
      };
      axios.get.mockResolvedValue({ data: { payload } });

      await actions.get({ commit });

      expect(axios.get).toHaveBeenCalledWith(
        '/api/v1/conversations/unread_counts'
      );
      expect(commit.mock.calls).toEqual([
        [types.SET_CONVERSATION_UNREAD_COUNTS, payload],
      ]);
    });

    it('does not commit when API fails', async () => {
      axios.get.mockRejectedValue({ message: 'Incorrect header' });

      await actions.get({ commit });

      expect(commit).not.toHaveBeenCalled();
    });

    it('falls back to the unread conversation meta count when the feature is unavailable', async () => {
      axios.get
        .mockRejectedValueOnce({ response: { status: 403 } })
        .mockResolvedValueOnce({ data: { meta: { all_count: 352 } } });

      await actions.get({ commit });

      expect(axios.get).toHaveBeenNthCalledWith(
        2,
        '/api/v1/conversations/meta',
        {
          params: {
            inbox_id: undefined,
            status: 'all',
            assignee_type: 'all',
            labels: undefined,
            team_id: undefined,
            conversation_type: 'unread',
          },
        }
      );
      expect(commit).toHaveBeenCalledWith(
        types.SET_ALL_CONVERSATION_UNREAD_COUNT,
        352
      );
    });
  });

  describe('#clear', () => {
    it('clears unread counts', () => {
      actions.clear({ commit });

      expect(commit).toHaveBeenCalledWith(
        types.SET_CONVERSATION_UNREAD_COUNTS,
        {}
      );
    });
  });
});

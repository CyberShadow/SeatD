module tango.scrapple.util.uuid.SharedSemaphore;

import tango.core.Exception;

version (Linux)
{
    class SharedSemaphore
    {
        private
        {
            sem_t* _handle = SEM_FAILED;
            char[] _name;
        }

        this(char[] name, uint count = 1)
        {
            _name = name.dup ~ "\0";
        }

          private void create(uint count)
          {
             _handle = sem_open(_name.ptr, O_CREAT, 0770, count);
             if (_handle == SEM_FAILED)
                throw new SyncException(strings[StringID.SemOpenFailed]);
          }

          void wait()
          {
             if (sem_wait(_handle) == -1)
                throw new SyncException("Semaphore wait failed");
          }

          void post()
          {
             sem_post(_handle);
          }

          sem_t* handle()
          {
             return _handle;
          }

          void close(bool unlink = false)
          {
             if (unlink)
                sem_unlink(_name.ptr);

             sem_close(_handle);
             _handle = null;
          }



}
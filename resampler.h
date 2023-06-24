#ifndef RESAMPLE_H
#define RESAMPLE_H

#include <vector>
#include <stdexcept>
#include <algorithm>
#include <limits>

#include <samplerate.h>

inline size_t get_max_resampled_frames(size_t src_frames,
                                       uint   src_sample_rate,
                                       uint   dst_sample_rate)
{
return ((src_frames * dst_sample_rate) / src_sample_rate) + 1;
}

class resampler
{
public:
    resampler(int converter_type, int channels, size_t initial_capacity = 0)
        : m_source_rate(0),
          m_dest_rate(0)
    {
        if (initial_capacity > 0)
        {
            m_resampled_data.reserve(initial_capacity);
            m_data_to_resample.reserve(initial_capacity);
        }

        int err = 0;
        m_state = src_new(converter_type, channels, &err);
        if (m_state == nullptr)
        {
            throw std::runtime_error("Could not initialize sample converter");
        }
    }
    ~resampler()
    {
        src_delete(m_state);
    }

    void set_sample_rates(uint source_rate, uint dest_rate)
    {
        m_source_rate = source_rate;
        m_dest_rate = dest_rate;
    }

    void enqueue(const float* data, size_t count)
    {
        if (count == 0)
        {
            return;
        }
        else if (m_source_rate == m_dest_rate)
        {
            m_resampled_data.insert(m_resampled_data.end(), data, data + count);
        }
        else
        {
            m_data_to_resample.insert(m_data_to_resample.end(), data, data + count);

            do_resample();
        }
    }

    void enqueue(const short* data, size_t count)
    {
        if (count == 0)
        {
            return;
        }
        else if (m_source_rate == m_dest_rate)
        {
            const size_t prev_size = m_resampled_data.size();
            m_resampled_data.resize(prev_size + count);
            src_short_to_float_array(data,
                                     m_resampled_data.data() + prev_size,
                                     count);
        }
        else
        {
            const size_t prev_size = m_data_to_resample.size();
            m_data_to_resample.resize(prev_size + count);
            src_short_to_float_array(data,
                                     m_data_to_resample.data() + prev_size,
                                     count);

            do_resample();
        }
    }

    bool dequeue(float* data, size_t count)
    {
        if (count == 0)
        {
            return true;
        }
        else if (count <= available_elems())
        {
            const auto cend = m_resampled_data.cbegin() + count;
            std::copy(m_resampled_data.cbegin(), cend, data);
            m_resampled_data.erase(m_resampled_data.cbegin(), cend);
            return true;
        }
        else
        {
            return false;
        }
    }

    bool dequeue(short* data, size_t count)
    {
        if (count == 0)
        {
            return true;
        }
        else if (count <= available_elems())
        {
            src_float_to_short_array(m_resampled_data.data(), data, count);
            m_resampled_data.erase(m_resampled_data.cbegin(),
                                   m_resampled_data.cbegin() + count);
            return true;
        }
        else
        {
            return false;
        }
    }

    size_t available_elems() const
    {
        return m_resampled_data.size();
    }

private:

    void do_resample()
    {
        const uint max_output_frames =
            get_max_resampled_frames(m_data_to_resample.size(),
                                     m_source_rate,
                                     m_dest_rate);

        const size_t prev_resampled_size = m_resampled_data.size();

        m_resampled_data.resize(prev_resampled_size + max_output_frames);

        SRC_DATA resample_parms;
        resample_parms.data_in = m_data_to_resample.data();
        resample_parms.data_out = m_resampled_data.data() + prev_resampled_size;

        resample_parms.input_frames = m_data_to_resample.size();
        resample_parms.output_frames = max_output_frames;

        resample_parms.end_of_input = 0;

        resample_parms.src_ratio = (double)m_dest_rate / (double)m_source_rate;

        if (src_process(m_state, &resample_parms) != 0)
        {
            throw std::runtime_error("Error resampling data");
            return;
        }

        if (resample_parms.output_frames_gen < resample_parms.output_frames)
        {
            const size_t valid_samples =
                prev_resampled_size + resample_parms.output_frames_gen;
            m_resampled_data.erase(m_resampled_data.begin() + valid_samples,
                                   m_resampled_data.end());
        }

        m_data_to_resample.erase(m_data_to_resample.begin(),
                                 m_data_to_resample.begin() + resample_parms.input_frames_used);
    }

private:
    uint m_source_rate;
    uint m_dest_rate;

    std::vector<float> m_data_to_resample;
    std::vector<float> m_resampled_data;

    SRC_STATE* m_state;
};

#endif

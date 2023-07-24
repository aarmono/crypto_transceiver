#ifndef DEBOUNCE_H
#define DEBOUNCE_H

class debounce
{
public:
    debounce(unsigned int integrator_max, bool initial_value = false)
        : m_integrator_max(integrator_max),
          m_integrator_val(initial_value ? integrator_max : 0),
          m_value(initial_value)
    {
    }

    bool add_value(bool val)
    {
        if (val == false && m_integrator_val > 0)
        {
            --m_integrator_val;
        }
        else if (val == true && m_integrator_val < m_integrator_max)
        {
            ++m_integrator_val;
        }

        if (m_integrator_val == 0)
        {
            m_value = false;
        }
        else if (m_integrator_val >= m_integrator_max)
        {
            m_value = true;
        }

        return m_value;
    }

    void reset(bool initial_value = false)
    {
        m_value = initial_value;
        m_integrator_val = initial_value ? m_integrator_max : 0;
    }

private:
    const unsigned int m_integrator_max;
    unsigned int       m_integrator_val;
    bool               m_value;
};

#endif

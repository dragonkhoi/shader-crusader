using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class DisplayText : MonoBehaviour
{
    public MeshRenderer rend;
    public string propertyName;
    public string display;
    public Transform lightTrans;
    private Text text;
    MaterialPropertyBlock propertyBlock;

    // Start is called before the first frame update
    void Start()
    {
        text = GetComponent<Text>();
        propertyBlock = new MaterialPropertyBlock();

    }

    // Update is called once per frame
    void Update()
    {
        if (propertyName == "LightAngle")
        {
            text.text = display + " " + lightTrans.rotation.eulerAngles.y;
        }
        else
        {
            rend.GetPropertyBlock(propertyBlock);
            text.text = display + " " + propertyBlock.GetFloat(propertyName);
        }
    }
}

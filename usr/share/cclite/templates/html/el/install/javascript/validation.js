<script language="JavaScript">
<!--				

var new_fieldname = ""

function check(form,x)
{
	//If you would like to use this script please do not remove the next 4 lines
	script_name = "Form Validator ver 2.0"
	action =  "Checks Required, Integer and Date"
	copyright = "(c) 1998 - Art Lubin / Artswork"
	email = "perflunk@aol.com"
	var set_up_var = doall(script_name, copyright, email)
	var message = ""
	var more_message = ""
	var showmsg = "no"
	if (set_up_var == 5872)
	{
		x = x - 1
		for (var i = 0; i <= x; i++)
			{
	 			var messenger = form.elements[i].name
				messenger = messenger.substring(0, 2)
				var fieldname = form.elements[i].name
				fieldname = fieldname.substring(2)

					{
						if (messenger == "r_")
							{
								more_message = r_check(form,x,fieldname,i)
							}
						else if (messenger == "i_")
							{
								more_message = i_check(form,x,fieldname,i)
							}
						else if (messenger == "d_")
								{
									more_message = d_check(form,x,fieldname,i)
								}
						else if (messenger == "e_")
								{
									more_message = e_check(form,x,fieldname,i)
								}			
							 if (more_message != "")
	        {
									if (message == "")
										{
											message = more_message
											more_message=""
										}
									else
										{
			        message = message + "\n" + more_message
											more_message=""
										}
	        }
											
						if (message > "")
								{
										showmsg = "yes"
								}													
						}	
				}
			
		
		//This code will prevent a submit if data is incoorect
		if (showmsg == "yes")
			{
				alert("The following form field(s) were incomplete or incorrect:\n\n" + message + "\n\n Please complete or correct the form and submit again.")
			}
		else
			{
				form.submit()
			}
			
			
			//This code will just warn and then submit if OK is selected.
		//if (showmsg == "yes")
			//{
				//if (confirm("The following form field(s) were incomplete or incorrect:\n\n" + message + "\n\n Please complete or correct the form and submit again."))
				
				//form.submit()
			//}
		//else
			//{
			//form.submit()
			//}
			
					
			
		}
	else
		{
			alert ("The copyright information has been changed. \n In order to use this javascript please keep the copyright information intact. \n\n Script Name: Form Validator ver 2.0 \n Copyright: (c) 1998 - Art Lubin / Artswork \n Email: perflunk@aol.com")
		}
}	

function r_check(form,x,fieldname,i)
	{
		var msg_addition = ""
		new_fieldname = fieldname
		for (var y = 0; y <= x; y++)
			{

				if ((form.elements[y].type == "radio" || form.elements[y].type == "checkbox") && form.elements[y].name == new_fieldname && form.elements[y].checked == true)
					{
							msg_addition = ""
							break
					}
				else if ((form.elements[y].type == "radio" || form.elements[y].type == "checkbox") && form.elements[y].name == new_fieldname && form.elements[y].checked == false)
					{
						msg_addition = form.elements[i].value
					}

			else if (form.elements[y].type == "select-one")
							{
								var l = form.elements[y].selectedIndex
								if (form.elements[y].name == fieldname && form.elements[y].options[l].value != "")
									{
										msg_addition = ""
										break
									}
								else if (form.elements[y].name == fieldname && form.elements[y].options[l].value == "")
									{
										
										msg_addition = form.elements[i].value

									}
								}
		 else if (form.elements[y].name == fieldname && form.elements[y].value == "" && form.elements[y].type != "radio" && form.elements[y].type != "checkbox" && form.elements[y].type != "select-one")
							{
								
								msg_addition = form.elements[i].value
								break
							}
				else if (form.elements[y].name == fieldname && form.elements[y].value != "" && form.elements[y].type != "radio" && form.elements[y].type != "checkbox" && form.elements[y].type != "select-one")
							{
								msg_addition = ""

							}	
				}
			return(msg_addition)
		}
			
			
function i_check(form,x,fieldname,i)
	{
		for (var y = 0; y <= x; y++)
			{
				if (form.elements[y].name == fieldname)
				break
			}						
	
	var msg_addition = ""
	var decimal = ""
	inputStr = form.elements[y].value.toString()
	
	if (inputStr == "")
		{
			//msg_addition = form.elements[i].value
		}
	else
		{
			for (var c = 0; c < inputStr.length; c++)
				{
					var oneChar = inputStr.charAt(c)
					if (c == 0 && oneChar == "-" || oneChar == "."  && decimal == "")
							{
								if (oneChar == ".")
									{
										decimal = "yes"
									}
								continue
								
							}
								if (oneChar < "0" || oneChar > "9")
									{
										msg_addition = form.elements[i].value
									}
				}
		}
		return(msg_addition)
	}	
	
	
	//Email validation added 6/20/98
	function e_check(form,x,fieldname,i)
	{
		for (var y = 0; y <= x; y++)
			{
				if (form.elements[y].name == fieldname)
				break
			}						
		
	var msg_addition = ""
	period = ".";

                
                if (form.elements[y].value == "" || form.elements[y].value.indexOf ('@', 0) < 3)
                        error = 1;
																						
																else
                  {
	                   test = form.elements[y].value.indexOf('.', form.elements[y].value.indexOf ('@', 0))
										 if (test != -1)
																					{
																						error = 0;
																					}
																				else
																				{
	                    	 error=1;
																				}
                  }
                if (error == 1)
																	{
               				msg_addition = form.elements[i].value
																	}
                else
                 {
								 		new_length = form.elements[y].value.length - test
             if (new_length == 4 || new_length == 3 || (new_length >= 5 && form.elements[y].value.indexOf ('.', (test+1)) != -1))
																						{
																							msg_addition = ""
																						}
																					else
																							msg_addition = form.elements[i].value;
																	}
	return(msg_addition)
	}	

	function d_check(form,x,fieldname,i)
//date must be in MM/DD/YY format OR M/D/YY or a MIX of the two
 {
		for (var y = 0; y <= x; y++)
			{
				if (form.elements[y].name == fieldname)
				break
			}		
			
		var msg_addition = ""	
		var sDate = form.elements[y].value
		var int_or_not = isInteger(form.elements[y].value)
		
		//to allow NO validation unless r_ specified
		if (form.elements[y].value != "") {
		
		if (int_or_not == "true")
			{
				if ((!(form.elements[y].value.length >= 6)) || (!(form.elements[y].value.length <= 8)))
   		{
    		msg_addition = form.elements[i].value
   		}
  		else
   		{
					 var SlashlPos = form.elements[y].value.indexOf("/",0)
						if (SlashlPos > 0 && SlashlPos <= 2)
							{
								if (SlashlPos == 1)
									{
										if (form.elements[y].value.charAt(0) < 1 || form.elements[y].value.charAt(0) > 9)
											{
												msg_addition = form.elements[i].value
											}
										else
											{
												if ((form.elements[y].value.charAt(0) == 1 || form.elements[y].value.charAt(0) == 3 || form.elements[y].value.charAt(0) == 5 || form.elements[y].value.charAt(0) == 7 || form.elements[y].value.charAt(0) == 8) && ((form.elements[y].value.charAt(2) == 0 && form.elements[y].value.charAt(3) == "/") || (form.elements[y].value.charAt(3) == "/" && form.elements[y].value.length >= 7) || (form.elements[y].value.charAt(1) == "/" && form.elements[y].value.charAt(2) == "/")))
													{ 
														msg_addition = form.elements[i].value
													}
												else if ((form.elements[y].value.charAt(0) == 1 || form.elements[y].value.charAt(0) == 3 || form.elements[y].value.charAt(0) == 5 || form.elements[y].value.charAt(0) == 7 || form.elements[y].value.charAt(0) == 8) && ((form.elements[y].value.charAt(2) >= 3 && form.elements[y].value.charAt(3) > 1) || (form.elements[y].value.charAt(2) == 0 && form.elements[y].value.charAt(3) == 0) || (form.elements[y].value.charAt(1) == "/" && (form.elements[y].value.charAt(3) != "/" && form.elements[y].value.charAt(4) != "/" && form.elements[y].value.charAt(5) != "/" && form.elements[y].value.charAt(6) != "/"))))
													{ 
														msg_addition = form.elements[i].value + "hi"
													}
												else if ((form.elements[y].value.charAt(0) == 1 || form.elements[y].value.charAt(0) == 3 || form.elements[y].value.charAt(0) == 5 || form.elements[y].value.charAt(0) == 7 || form.elements[y].value.charAt(0) == 8) && (((form.elements[y].value.charAt(2) > 3 && form.elements[y].value.charAt(3) != "/") || (((form.elements[y].value.charAt(1) == "/" && form.elements[y].value.charAt(4) == "/")) && ((form.elements[y].value.length == 6 || form.elements[y].value.length == 8)))) || form.elements[y].value.charAt(5) == "/"))
													{
														msg_addition = form.elements[i].value
													}
												else
													{
														if ((form.elements[y].value.charAt(0) == 2 && ((form.elements[y].value.charAt(2) == 0 && form.elements[y].value.charAt(3) == "/") || (form.elements[y].value.charAt(3) == "/" && form.elements[y].value.length >= 7) || (form.elements[y].value.charAt(1) == "/" && form.elements[y].value.charAt(2) == "/") || (form.elements[y].value.charAt(2) == 0 && form.elements[y].value.charAt(3) == 0) || (form.elements[y].value.charAt(1) == "/" && (form.elements[y].value.charAt(3) != "/" && form.elements[y].value.charAt(4) != "/" && form.elements[y].value.charAt(5) != "/" && form.elements[y].value.charAt(6) != "/")))))
															{ 
																msg_addition = form.elements[i].value
															}
														else if (form.elements[y].value.charAt(0) == 2 && ((form.elements[y].value.charAt(2) > 2 && form.elements[y].value.charAt(3) != "/") || (((form.elements[y].value.charAt(1) == "/" && form.elements[y].value.charAt(4) == "/") && ((form.elements[y].value.length == 6 || form.elements[y].value.length == 8)))) || form.elements[y].value.charAt(5) == "/"))
															{ 
																msg_addition = form.elements[i].value
															}
														else
															{
																if ((form.elements[y].value.charAt(0) == 4 || form.elements[y].value.charAt(0) == 6 || form.elements[y].value.charAt(0) == 9) && ((form.elements[y].value.charAt(2) == 0 && form.elements[y].value.charAt(3) == "/") || (form.elements[y].value.charAt(3) == "/" && form.elements[y].value.length >= 7) || (form.elements[y].value.charAt(1) == "/" && form.elements[y].value.charAt(2) == "/")))
																	{ 
																		msg_addition = form.elements[i].value
																	}
																else if ((form.elements[y].value.charAt(0) == 4 || form.elements[y].value.charAt(0) == 6 || form.elements[y].value.charAt(0) == 9) && ((form.elements[y].value.charAt(2) >= 3 && form.elements[y].value.charAt(3) > 0) || (form.elements[y].value.charAt(2) == 0 && form.elements[y].value.charAt(3) == 0) || (form.elements[y].value.charAt(1) == "/" && (form.elements[y].value.charAt(3) != "/" && form.elements[y].value.charAt(4) != "/" && form.elements[y].value.charAt(5) != "/" && form.elements[y].value.charAt(6) != "/"))))
																	{ 
																		msg_addition = form.elements[i].value
																	}
																else if ((form.elements[y].value.charAt(0) == 4 || form.elements[y].value.charAt(0) == 6 || form.elements[y].value.charAt(0) == 9) && (((form.elements[y].value.charAt(2) > 3 && form.elements[y].value.charAt(3) != "/") || ((form.elements[y].value.charAt(1) == "/" && form.elements[y].value.charAt(4) == "/") && ((form.elements[y].value.length == 6 || form.elements[y].value.length == 8)))) || form.elements[y].value.charAt(5) == "/"))
																	{
																		msg_addition = form.elements[i].value
																	}
															}
													}
											}
									}
								else
									{
										if (form.elements[y].value.charAt(0) > 1 || (form.elements[y].value.charAt(0) == 1 && form.elements[y].value.charAt(1) > 2) || (form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 0))
											{
												msg_addition = form.elements[i].value
											}
										else
											{
												if (((form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 1) || (form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 3) || (form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 5) || (form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 7) || (form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 8) || (form.elements[y].value.charAt(0) == 1 && form.elements[y].value.charAt(1) == 0) || (form.elements[y].value.charAt(0) == 1 && form.elements[y].value.charAt(1) == 2)) && ((form.elements[y].value.charAt(3) == 0 && form.elements[y].value.charAt(4) == "/") || (form.elements[y].value.charAt(2) == "/" && form.elements[y].value.charAt(3) == "/") || (form.elements[y].value.charAt(2) == "/" && (form.elements[y].value.charAt(4) != "/" && form.elements[y].value.charAt(5) != "/" && form.elements[y].value.charAt(6) != "/" && form.elements[y].value.charAt(7) != "/"))))
													{
														msg_addition = form.elements[i].value		
													}
												else if (((form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 1) || (form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 3) || (form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 5) || (form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 7) || (form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 8) || (form.elements[y].value.charAt(0) == 1 && form.elements[y].value.charAt(1) == 0) || (form.elements[y].value.charAt(0) == 1 && form.elements[y].value.charAt(1) == 2)) && ((form.elements[y].value.charAt(3) >= 3 && form.elements[y].value.charAt(4) > 1) || (form.elements[y].value.charAt(3) == 0 && form.elements[y].value.charAt(4) == 0) || form.elements[y].value.length < 7))
													{
														msg_addition = form.elements[i].value
													}
												else if (((form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 1) || (form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 3) || (form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 5) || (form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 7) || (form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 8) || (form.elements[y].value.charAt(0) == 1 && form.elements[y].value.charAt(1) == 0) || (form.elements[y].value.charAt(0) == 1 && form.elements[y].value.charAt(1) == 2)) && ((form.elements[y].value.charAt(3) > 3 && form.elements[y].value.charAt(4) != "/")	|| ((form.elements[y].value.charAt(2) == "/" && form.elements[y].value.charAt(5) == "/" && form.elements[y].value.length == 7 || form.elements[y].value.charAt(6) == "/") || (form.elements[y].value.charAt(2) == "/" && form.elements[y].value.charAt(4) == "/" && (form.elements[y].value.length == 6 || form.elements[y].value.length == 8)))))
													{
														msg_addition = form.elements[i].value
													}
												else
													{
														if (((form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 2) && ((form.elements[y].value.charAt(3) == 0 && form.elements[y].value.charAt(4) == "/") || (form.elements[y].value.charAt(3) == 0 && form.elements[y].value.charAt(4) == 0)) || form.elements[y].value.length < 7) || (form.elements[y].value.charAt(2) == "/" && (form.elements[y].value.charAt(4) != "/" && form.elements[y].value.charAt(5) != "/" && form.elements[y].value.charAt(6) != "/" && form.elements[y].value.charAt(7) != "/")))
															{
																msg_addition = form.elements[i].value
															}
														else if ((form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 2) && ((form.elements[y].value.charAt(3) > 2 && form.elements[y].value.charAt(4) != "/") || ((form.elements[y].value.charAt(2) == "/" && form.elements[y].value.charAt(5) == "/" && form.elements[y].value.length == 7 || form.elements[y].value.charAt(6) == "/") || (form.elements[y].value.charAt(2) == "/" && form.elements[y].value.charAt(4) == "/" && (form.elements[y].value.length == 6 || form.elements[y].value.length == 8)))))
															{
																msg_addition = form.elements[i].value
															}
														else
															{			
																if (((form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 4) || (form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 6) || (form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 9) || (form.elements[y].value.charAt(0) == 1 && form.elements[y].value.charAt(1) == 1)) && ((form.elements[y].value.charAt(3) == 0 && form.elements[y].value.charAt(4) == "/") || (form.elements[y].value.charAt(2) == "/" && form.elements[y].value.charAt(3) == "/") || (form.elements[y].value.charAt(2) == "/" && (form.elements[y].value.charAt(4) != "/" && form.elements[y].value.charAt(5) != "/" && form.elements[y].value.charAt(6) != "/" && form.elements[y].value.charAt(7) != "/"))))
																	{
																		msg_addition = form.elements[i].value
																	}
																else if (((form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 4) || (form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 6) || (form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 9) || (form.elements[y].value.charAt(0) == 1 && form.elements[y].value.charAt(1) == 1)) && ((form.elements[y].value.charAt(3) >= 3 && form.elements[y].value.charAt(4) > 0) || (form.elements[y].value.charAt(3) == 0 && form.elements[y].value.charAt(4) == 0) || form.elements[y].value.length < 7))
																	{
																		msg_addition = form.elements[i].value
																	}
																else if (((form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 4) || (form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 6) || (form.elements[y].value.charAt(0) == 0 && form.elements[y].value.charAt(1) == 9) || (form.elements[y].value.charAt(0) == 1 && form.elements[y].value.charAt(1) == 1)) && ((form.elements[y].value.charAt(3) > 3 && form.elements[y].value.charAt(4) != "/") || ((form.elements[y].value.charAt(2) == "/" && form.elements[y].value.charAt(5) == "/" && form.elements[y].value.length == 7 || form.elements[y].value.charAt(6) == "/") || (form.elements[y].value.charAt(2) == "/" && form.elements[y].value.charAt(4) == "/" && (form.elements[y].value.length == 6 || form.elements[y].value.length == 8)))))
																	{
																		msg_addition = form.elements[i].value
																	}
															}
													}		
											}
									}
							}
		    else
							{
								msg_addition = form.elements[i].value
							}
					}
			}
		else
			{
				msg_addition = form.elements[i].value
			}
		return(msg_addition)
	}
	
	//to allow NO validation unless r_ specified CLOSING
	return(msg_addition)
	}
	
	function isInteger(sDate)
	{
		var new_msg = "true"
		inputStr = sDate.toString()
		for (var i = 0; i < inputStr.length; i++)
			{
			var oneChar = inputStr.charAt(i)			
			if ((oneChar < "0" || oneChar > "9") && oneChar != "/")
					{
						new_msg = "false"
					}
			}
		return (new_msg)
	}
	
	function doall(script_name, copyright, email)
	{
	var code = 0
	var test = script_name + copyright + email
	for (var a = 0; a < test.length; a++)
		{
		var each_char = test.charAt(a)
		var x = asc(each_char)
		code += x
		}
	return (code)
	}
	
	function asc(each_char)
		{
		var n = 0
			var char_str = charSetStr()
			for (i = 0; i < char_str.length; i++)
				{
					if (each_char == char_str.substring(i, i+1))
						{
							break
						}
				}
			return i + 32
		}
		
		function charSetStr()
			{
				var str
 			str = ' !"#$%&' + "'" + '()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~'
				return str
			}
	
//-->
</script>

